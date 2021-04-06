import 'dart:convert' show LineSplitter, utf8, jsonDecode, jsonEncode;
import 'dart:io';
import 'dart:async';

InternetAddress HOST = InternetAddress.loopbackIPv4;
const PORT = 7654;

const room0 = '_r0';
void main(List<String> argv) {
  //Parámetros 'alias de cliente/dummy' 'Server IP/127.0.0.1'
  var alias = argv.length > 0 ? argv[0] : Platform.localHostname;
  if (argv.length > 1) HOST = InternetAddress(argv[1]);

  // envio de un mensaje convertido en Json
  void sendMsg(Socket socket, String room, String action, dynamic value,
      [Map data = const {}]) {
    var msg = Map();
    if (room != room0) msg['room'] = room;
    msg["action"] = action;
    msg["value"] = value.toString();
    msg.addAll(data);
    socket.write('${jsonEncode(msg)}\n');
  }

  // Nos conectamos al servidor
  Socket.connect(HOST, PORT).then((socket) async {
    print('Connected to ${HOST.address}:$PORT');

    print('Socket.Address.Port: ${socket.address.address}:${socket.port}');

    // Nos presentamos al servidor
    sendMsg(socket, room0, 'ALIAS', alias);

    // Establecemos los listeners onData, onDone, onError
    socket.cast<List<int>>().transform(utf8.decoder).listen(onData, onDone: () {
      print("onDone: Servidor cerrado");
      socket.close();
      exit(0);
    }, onError: (error) {
      print('onError: $error');
    });

    // Ciclo sincrono de lectura del teclado.
    // Cuando 'quit' es cuando salimos del ciclo.
    await getStdinData(socket, sendMsg);
    print('fin getStdinData:');

    // El cliente sale e informamos que nos vamos
    sendMsg(socket, room0, 'QUIT', '');

    // Cerramos el socket y fin cliente
    socket.close();
    exit(0);
  }).catchError((error) {
    print('Servidor no activo');
    print('catchError: $error');
    exit(0);
  });
}

onData(data) {
  LineSplitter ls = new LineSplitter();
  List<String> lines = ls.convert(data);
  lines.forEach((line) {
    var json = jsonDecode(line);
    print('onData: $json');
    // if (json['action'] == 'CLIENTS') {
    //   var value = jsonDecode(json['value']);
    //   print(value[0]);
    // }
  });
}

// Lectura de teclado de LineSplitter
getStdinData(Socket socket, Function sendMsg) async {
  //stdout.write("Mensaje: ");
  //https://stackoverflow.com/questions/64314020/i-need-an-idiomatic-solution-in-dart-on-a-client-socket-application

  // Una funcion para leer una linea de la consola
  Stream readLine() =>
      stdin.transform(utf8.decoder).transform(const LineSplitter());

  // por cada linea enviamos un mensaje
  await for (var msg in readLine()) {
    if (msg == '') continue; //<- si vacio volvemos al comienzo
    if (msg.toString().toLowerCase() == 'quit')
      return (0); //<- si 'quit' acabamos

    var room = room0;
    if (msg.indexOf('|') > -1) {
      room = msg.split('|')[0];
      msg = msg.split('|')[1];
    }

    var action = 'MSG';
    if (msg.indexOf(':') > -1) {
      action = msg.split(':')[0].toUpperCase();
      msg = msg.split(':')[1];
    }

    if (msg.indexOf('@') > -1) {
      var value = msg.split('@')[0];
      var to = msg.split('@')[1]; //uno;dos;tres;cuatro
      sendMsg(socket, room, action, value, {'to': to});
    } else
      sendMsg(socket, room, action, msg);

    //stdout.write("Mensaje: ");
  }
}
