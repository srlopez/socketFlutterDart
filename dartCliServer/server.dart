import 'dart:io';
import 'dart:convert' show utf8, jsonDecode, jsonEncode;

InternetAddress HOST = InternetAddress.loopbackIPv4;
const PORT = 7654;

var db = ClientesDB();

// Muesta la lista de interfces y las Ip asignadas
// Si se pasa una interface estable la variable HOST con la ip de la interface
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

  // Y se pone a escuchar. Por cada conexion/bin lanza un lambda para cada cliente
  ServerSocket.bind(HOST, PORT).then((ServerSocket srv) {
    printServer('server on ${HOST.address}:${PORT}');
    srv.listen(handleClient);
  }).catchError(print);
}

// Una tonteria de función
void printServer(msg) {
  print('INFO: $msg');
}

// Ciclo ppal de manejo de conexión cliente
void handleClient(Socket client) {
  // envio de msg a un cliente
  void sendMsg(Socket client, String action, dynamic value,
      [Map data = const {}]) {
    var msg = Map();
    msg["action"] = action;
    msg["value"] = value.toString();
    msg.addAll(data);

    try {
      client.write('${jsonEncode(msg)}\n');
    } catch (e) {
      print('try client.write: $e');
    }
  }

  // broadcast a todos
  void sendMsgToAll(int from, String action, dynamic value,
      [Map data = const {}]) {
    var msg = Map();
    msg.addAll(data);
    msg['from'] = db.alias(from);
    db.items.forEach((id, client) {
      if (from != id) sendMsg(client.socket, action, value, msg);
    });
  }

  // Nueva conexión/LOGIN establecida
  void newConnetion(Socket client, String name) {
    db.add(client, name);
    printServer(
        'Connected ${db.alias(db.id(client))} on address.port: ${client.remoteAddress.address}:${client.remotePort}');

    sendMsg(client, 'CLIENT_COUNTER', db.length,
        {'from': db.alias(db.id(client)), 'clients': db.toString()});

    sendMsgToAll(db.id(client), 'CLIENT_COUNTER', db.length,
        {'from': 'Server', 'clients': db.toString()});
  }

  // onDone/Cloe/Quit
  void removeConnetion(Socket client) {
    sendMsgToAll(
        db.id(client), 'CLIENT_COUNTER', db.length, {'from': 'Server'});
    db.delete(client);
    printServer('${db.length} clients');
  }

  // onError!!
  void onError(e) {
    printServer('Error $e');
  }

  // onDone/Close conexxión
  void onDone() {
    printServer('disconnect from ${client.hashCode}');
    removeConnetion(client);
  }

  // Por cada mensaje
  void onData(String json) {
    //print('${client.hashCode} $json');
    try {
      Map msg = jsonDecode(json);

      switch (msg["action"]) {
        case 'LOGIN':
          newConnetion(client, msg['value'].toString().toLowerCase());
          break;
        case 'QUIT':
          // No hacemos NADA, el cierre del cliente enviá un onDone y CERRAMOS;
          break;
        case 'MSG':
          {
            var value = msg['value'].toString().toLowerCase();
            if (value == "") return; //Evitamos el mensaje void

            var toClient = msg['to'].toString().toLowerCase();
            if (toClient == 'all') {
              sendMsgToAll(db.id(client), '', '', msg);
            } else {
              //Por cada destinatario
              toClient.split(';').forEach((toString) {
                try {
                  var to = int.parse(toString);
                  if (db.find(to)) {
                    msg['to'] = db.alias(to);
                    msg['from'] = db.alias(db.id(client));
                    sendMsg(db.socket(to), '', '', msg);
                  }
                } catch (e) {}
              });
            }
          }
          break;
        default:
          sendMsg(client, 'ERROR', msg);
          break;
      }
    } catch (e) {
      print(e);
    }
  }

  // mostramos la conexion entrante
  // printServer(
  //     '${client.hashCode} connected from ${client.remoteAddress.address}:${client.remotePort}');

  // Establecemos el Ciclo de lectura de mensajes con los lambdas aquí definidos.
  client
      .cast<List<int>>()
      .transform(utf8.decoder)
      .listen(onData, onError: onError, onDone: onDone);
}

class Client<Socket, String> {
  final Socket client;
  final String nombre;

  Client(this.client, this.nombre);

  Socket get socket => client;
}

class ClientesDB {
  // hash -> (socket,nombre)
  var _memory = Map<int, Client<Socket, String>>();

  int _hash(Socket client) {
    return '${client.remoteAddress.address}:${client.remotePort}'.hashCode;
  }

  int id(Socket client) {
    return _hash(client);
  }

  void add(Socket client, String name) {
    int id = _hash(client);
    _memory[id] = Client(client, name);
  }

  // onDone/Close/Quit
  void delete(Socket client) {
    int id = _hash(client);
    _memory.remove(id);
    client.close();
    client.destroy();
  }

  String alias(int id) {
    var c = _memory[id];
    return '$id:${c!.nombre}';
  }

  bool find(int id) {
    return _memory.containsKey(id);
  }

  Socket socket(int id) {
    return _memory[id]!.socket;
  }

  String toString() {
    var result = _memory.entries
        .map<String>((e) => alias(e.key))
        .reduce((a, b) => '$a, $b');
    return '[ $result ]';
  }

  int get length => _memory.length;

  Map<int, Client<Socket, String>> get items => _memory;
}
