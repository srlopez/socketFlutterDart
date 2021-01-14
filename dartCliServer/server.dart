import 'dart:io';
import 'dart:convert' show utf8, jsonDecode, jsonEncode;

InternetAddress HOST = InternetAddress.loopbackIPv4;
const PORT = 7654;

// Lista de clientes conectados hash-socket
var connections = Map<int, Socket>();
// Lista de login conetados: hash-alias
// Esta aprosimación no permite el mismo alias para distintos clientes
var alias = Map<int, String>();

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
  void sendMsgToAll(int hashOrigen, String action, dynamic value,
      [Map data = const {}]) {
    var msg = Map();
    msg.addAll(data);
    msg['from'] = alias[hashOrigen];
    connections.forEach((hashCode, client) {
      if (hashOrigen != client.hashCode) sendMsg(client, action, value, msg);
    });
  }

  // Nueva conexión/LOGIN establecida
  void newConnetion(Socket client, String name) {
    connections[client.hashCode] = client;
    alias[client.hashCode] = name;
    sendMsg(client, 'CLIENT_COUNTER', connections.length,
        {'from': name, 'clients': alias.values.toList()});
    sendMsgToAll(client.hashCode, 'CLIENT_COUNTER', connections.length,
        {'from': 'Server', 'clients': alias.values.toList()});
  }

  // onDone/Cloe/Quit
  void removeConnetion(Socket client) {
    alias.remove(client.hashCode);
    connections.remove(client.hashCode);
    printServer('${connections.length} clients');
    sendMsgToAll(client.hashCode, 'CLIENT_COUNTER', connections.length,
        {'from': 'Server'});
    client.close();
    client.destroy();
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
    print('${client.hashCode} $json');
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
            var toClient = msg['to'].toString().toLowerCase();
            var value = msg['value'].toString().toLowerCase();
            if (value == "") return; //Evitamos el mensaje void
            if (toClient == 'all')
              sendMsgToAll(client.hashCode, '', '', msg);
            else {
              toClient.split(';').forEach((to) {
                MapEntry<int, String> entry = alias.entries.firstWhere(
                    (element) => element.value == to,
                    orElse: () => MapEntry(0, 'not found'));
                if (entry.key != 0) {
                  msg['to'] = to;
                  msg['from'] = alias[client.hashCode];
                  sendMsg(connections[entry.key]!, '', '', msg);
                }
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
  printServer(
      '${client.hashCode} connected from ${client.remoteAddress.address}:${client.remotePort}');

  // Establecemos el Ciclo de lectura de mensajes con los lambdas aquí definidos.
  client
      .cast<List<int>>()
      .transform(utf8.decoder)
      .listen(onData, onError: onError, onDone: onDone);
}
