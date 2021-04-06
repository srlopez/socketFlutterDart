import 'dart:io';
import 'dart:convert' show utf8, jsonDecode, jsonEncode;

import 'dart:math';

InternetAddress HOST = InternetAddress.loopbackIPv4;
const PORT = 7654;

var connections = ConnectionsList();

/*
 * Muesta la lista de interfces y las Ip asignadas
 * Si se pasa una interface estable la variable HOST con la ip de la interface
 * iface = nombre de la interfaz por la que escuchar.
*/
Future setIp([String iface = 'none']) async {
  for (var interface in await NetworkInterface.list()) {
    //print('== Interface: ${interface.name} ==');
    for (var addr in interface.addresses) {
      if (iface == 'none')
        print('${addr.type.name} ${addr.address} ${interface.name}');
      if (interface.name.toLowerCase() == iface && addr.type.name == 'IPv4')
        HOST = InternetAddress(addr.address);
    }
  }
}

void main(List<String> argv) async {
  // Muestra las interfaces
  setIp();
  // Establece la IP por la que escucha
  if (argv.length > 0) await setIp(argv[0].toLowerCase());

  // Y se pone a escuchar.
  // Por cada conexion/bind lanza 'handleClient' para cada cliente
  ServerSocket.bind(HOST, PORT).then((ServerSocket srv) {
    logInfo('server on ${HOST.address}:${PORT}');
    srv.listen(handleClient);
  }).catchError(print);
}

// Una tonteria de función
void logInfo(msg) {
  msg = msg.replaceAll('\n', ' ');
  print('INFO: $msg');
}

// Ciclo ppal de manejo de conexión cliente
void handleClient(Socket client) {
  // onError!!
  void onError(e) {
    logInfo('Error $e');
  }

  // onDone/Close conexxión
  void onDone() {
    connections.broadcastMsg(client, 'QUIT', connections.getId(client));
    connections.remove(client);
    client.close();
    client.destroy();
    logInfo('Count ${connections.count} clients');
  }

  // onData: Por cada mensaje
  void onData(String data) {
    try {
      Map msg = jsonDecode(data);

      String action = msg["action"].toString().toUpperCase();
      String value = msg['value'] ?? '';
      //Evitamos el mensaje void
      if (value == '') return;

      logInfo('$data ${connections.getAlias(client)}');

      var validChars = '!\$*+-^';
      var marca = action.substring(0, 1);
      marca = validChars.contains(marca) ? marca : '';

      switch (action) {
        case 'ALIAS':
          connections.setAlias(client, value);
          connections.broadcastMsg(
              client, 'ALIAS', connections.getAlias(client));
          connections.sendMsg(client, client, 'USERS', connections.toString());
          break;
        default:
          //Evitamos el mensaje de quien no se identifica
          if (connections.getAlias(client) == '') break;

          if (msg.containsKey('to')) {
            var to = msg['to'].toString();
            msg.remove('to');
            //Por cada destinatario
            to.split(';').forEach((id) {
              try {
                var socket = connections.getSocket(id);
                connections.sendMsg(client, socket, '', '', msg);
              } catch (e) {
                //Bad state: No element
                //FormatException: Invalid radix-10 number
              }
            });
          } else {
            if (marca == '')
              connections.broadcastMsg(client, '', '', msg);
            else {
              connections.setAction(client, action);
              connections.broadcastAction(client, action, msg);
            }
          }
      }
    } catch (e) {
      print(data);
      print(e);
    }
  }

  //
  logInfo(
      'Connected from ${client.remoteAddress.address}:${client.remotePort}');
  // Enviamos la ID
  connections.add(client);
  connections.sendMsg(client, client, 'ID', connections.getId(client));

  // Establecemos el Ciclo de lectura de mensajes con los lambdas aquí definidos.
  client
      .cast<List<int>>()
      .transform(utf8.decoder)
      .listen(onData, onError: onError, onDone: onDone);
}

class Client {
  final String id;
  String alias = '';
  var actions = Map<String, DateTime>();

  Client(socket)
      : id = '${socket.remoteAddress.address}:${socket!.remotePort}'
            .hashCode
            .toString();

  @override
  String toString() => jsonEncode({'id': int.parse(id), 'alias': alias});
}

class ConnectionsList {
  var _items = Map<Socket, Client>();
  int get count => _items.length;

  String add(Socket socket) {
    Client client = Client(socket);
    _items[socket] = client;
    return client.toString();
  }

  void remove(Socket socket) {
    _items.remove(socket);
  }

  Socket getSocket(String id) {
    print('===>$id ${id.runtimeType}');

    // var idi = int.parse(id);
    // String ids = id;
    var entry = _items.entries.firstWhere(
        (element) => (element.value.id == id || element.value.alias == id));
    return entry.key;
  }

  String getId(Socket socket) {
    return _items[socket]!.id;
  }

  String getAlias(Socket socket) {
    return _items[socket]!.alias;
  }

  void setAlias(Socket socket, String alias) {
    Random rnd = new Random();
    var base = alias.trim(); //.replaceAll(RegExp(r'[^A-Za-z0-9().,;?]'), '');
    var valid = base;
    while (true) {
      try {
        _items.entries.firstWhere((element) => element.value.alias == valid);
        valid = base + (1 + rnd.nextInt(98)).toString();
      } catch (e) {
        break;
      }
    }
    _items[socket]!.alias = valid;
  }

  @override
  String toString() {
    var result = _items.entries
        .map<String>((e) => e.value.toString())
        .reduce((a, b) => '$a, $b');
    return '[ $result ]';
  }

  void sendMsg(Socket from, Socket to, String action, dynamic value,
      [Map data = const {}]) {
    var msg = Map();
    msg['action'] = action;
    msg['value'] = value.toString();
    msg['from'] = int.parse(getId(from));
    msg['on'] = DateTime.now().toLocal().toString().substring(0, 19);
    msg.addAll(data);

    try {
      to.write('${jsonEncode(msg)}\n');
    } catch (e) {
      print('sendMsg: $e');
    }
  }

  void broadcastMsg(Socket from, String action, dynamic value,
      [Map data = const {}]) {
    var msg = Map();
    msg.addAll(data);
    _items.forEach((to, client) {
      // No nos reenviamos el msg
      if (from == to) return;
      sendMsg(from, to, action, value, msg);
    });
  }

  void setAction(Socket socket, String action) {
    _items[socket]!.actions[action] = DateTime.now();
  }

  void broadcastAction(Socket from, String action, Map data) {
    _items.forEach((to, client) {
      // No se envia el mensaje a quien comparte la suya.
      // O no lo ha hecho en un plazo de 1 minuto
      final segundos = 60;
      try {
        if (DateTime.now().difference(client.actions[action]!).inSeconds >
            segundos) return;
        if (from == to) return;
        sendMsg(from, to, '', '', data);
      } catch (e) {
        return;
      }
    });
  }
}
