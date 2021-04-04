import 'dart:io';
import 'dart:convert' show utf8, jsonDecode, jsonEncode;

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
  void onData(String json) {
    try {
      Map msg = jsonDecode(json);

      //Evitamos el mensaje void
      var value = msg['value'] ?? "";
      if (value == "") return;

      logInfo('$json <= ${connections.getId(client)}');

      switch (msg["action"]) {
        case 'ALIAS':
          connections.setAlias(client, value);
          connections.broadcastMsg(
              client, 'ALIAS', connections.getAlias(client));
          connections.sendMsg(client, client, 'USERS', connections.toString());
          break;
        case 'LATLNG':
          connections.setLocation(client, value);
          connections.broadcastLocation(client, msg);
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
                var socket = connections.getSocket(int.parse(id));
                connections.sendMsg(client, socket, '', '', msg);
              } catch (e) {
                //Bad state: No element
                //FormatException: Invalid radix-10 number
              }
            });
          } else
            connections.broadcastMsg(client, '', '', msg);
      }
    } catch (e) {
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
  final int id;
  String alias = '';
  String latlng = '';

  Client(socket)
      : id = '${socket.remoteAddress.address}:${socket!.remotePort}'.hashCode;

  @override
  String toString() => jsonEncode({'id': id, 'alias': alias});
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

  Socket getSocket(int id) {
    var entry = _items.entries.firstWhere((element) => element.value.id == id);
    return entry.key;
  }

  int getId(Socket socket) {
    return _items[socket]!.id;
  }

  String getAlias(Socket socket) {
    return _items[socket]!.alias;
  }

  void setAlias(Socket socket, String alias) {
    _items[socket]!.alias = alias;
  }

  void setLocation(Socket socket, String location) {
    _items[socket]!.latlng = location;
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
    msg['from'] = getId(from);
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
      if (from != to) sendMsg(from, to, action, value, msg);
    });
  }

  void broadcastLocation(Socket from, Map data) {
    var msg = Map();
    msg.addAll(data);
    _items.forEach((to, client) {
      // No se envia locacizaciones a quien comparte la suya.
      if ((from != to) && (client.latlng != '')) sendMsg(from, to, '', '', msg);
    });
  }
}
