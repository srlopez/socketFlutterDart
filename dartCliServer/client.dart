import 'dart:convert' show LineSplitter, utf8, jsonDecode, jsonEncode;
import 'dart:io';
import 'dart:async';

InternetAddress HOST = InternetAddress.loopbackIPv4;
const PORT = 7654;
void main(List<String> argv) {
  //Parámetros 'alias de cliente/dummy' 'Server IP/127.0.0.1'
  var alias = argv.length > 0 ? argv[0] : 'dummy';
  if (argv.length > 1) HOST = InternetAddress(argv[1]);

  // envio de un mensaje convertido en Json
  void sendMsg(Socket socket, String action, dynamic value,
      [Map data = const {}]) {
    var msg = Map();
    msg["action"] = action;
    msg["value"] = value.toString();
    msg.addAll(data);
    socket.write('${jsonEncode(msg)}\n');
  }

  // Nos conectamos al servidor
  Socket.connect(HOST, PORT).then((socket) async {
    print('connected to ${HOST.address}:$PORT');

    // Nos presentamos al servidor
    sendMsg(socket, 'LOGIN', alias, {
      "localHostname": Platform.localHostname,
      "operatingSystem": Platform.operatingSystem,
      "operatingSystemVersion": Platform.operatingSystemVersion
    });

    // Establecemos los listeners onData, onDone, onError
    socket.cast<List<int>>().transform(utf8.decoder).listen(onData, onDone: () {
      print("onDone: Cerrado el servidor");
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
    sendMsg(socket, 'QUIT', '');

    // Cerramos el socket y fin cliente
    socket.close();
    exit(0);
  }).catchError((error) {
    print('Servidor no activo');
    print('catchError: $error');
    exit(0);
  });
}

onData(json) {
  //Recibimos un msg
  var data = jsonDecode(json);
  print('onData: $data');
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

    if (msg.indexOf('@') > -1) {
      var value = msg.split('@')[0];
      var to = msg.split('@')[1]; //uno;dos;tres;cuatro
      sendMsg(socket, 'MSG', value, {'to': to});
    } else
      sendMsg(socket, 'MSG', msg, {'to': 'ALL'});

    //stdout.write("Mensaje: ");
  }
}
