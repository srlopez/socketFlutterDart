import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get_ip/get_ip.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          primarySwatch: Colors.lightGreen,
        ),
        home: SocketClient());
  }
}

SocketClientState pageState;

class SocketClient extends StatefulWidget {
  @override
  SocketClientState createState() {
    pageState = SocketClientState();
    return pageState;
  }
}

class SocketClientState extends State<SocketClient> {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  List<MessageItem> items = [];
  var users = <int, String>{0: "SYSTEM"};

  String localIP;
  int port = 7654;
  var alias = 'soymovil';
  int meId = 0;

  TextEditingController ipCon = TextEditingController(text: "10.0.2.2");
  TextEditingController msgCon = TextEditingController();
  var logincontroller = TextEditingController(text: 'SoyMovil');

  Socket socket;

  @override
  void initState() {
    super.initState();
    getIP();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadServerIP();
    });
  }

  @override
  void dispose() {
    disconnectFromServer();
    super.dispose();
  }

  void getIP() async {
    var ip = await GetIp.ipAddress;
    setState(() {
      localIP = ip;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: scaffoldKey,
        appBar: AppBar(title: Text("Socket Client $localIP")),
        body: Column(
          children: <Widget>[
            loginArea(),
            connectArea(),
            messageListArea(),
            submitArea(),
          ],
        ));
  }

  Widget loginArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18.0, 5, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Alias:', style: TextStyle(fontWeight: FontWeight.bold)),
          TextField(
            controller: logincontroller,
          ),
        ],
      ),
    );
  }

  Widget connectArea() {
    return Card(
      child: ListTile(
        dense: true,
        leading: Text("Server IP"),
        title: TextField(
          controller: ipCon,
          decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              isDense: true,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(5)),
                borderSide: BorderSide(color: Colors.grey[300]),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(5)),
                borderSide: BorderSide(color: Colors.grey[400]),
              ),
              filled: true,
              fillColor: Colors.grey[50]),
        ),
        trailing: ElevatedButton(
          child: Text((socket != null) ? "Disconnect" : "Connect"),
          onPressed: (socket != null) ? disconnectFromServer : connectToServer,
        ),
      ),
    );
  }

  Widget messageListArea() {
    return Expanded(
      child: ListView.builder(
          reverse: true,
          itemCount: items.length,
          itemBuilder: (context, index) {
            MessageItem item = items[index];

            return Container(
              alignment: (item.owner == meId)
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: (item.type != 'MSG')
                        ? Colors.lightBlueAccent[400]
                        : (item.owner == meId)
                            ? Colors.lightGreen[600]
                            : Colors.grey[600]),
                child: Column(
                  crossAxisAlignment: (item.owner == meId)
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${item.type}: ${users[item.owner]}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white70),
                    ),
                    Text(
                      item.content,
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ],
                ),
              ),
            );
          }),
    );
  }

  Widget submitArea() {
    return Card(
      child: ListTile(
        title: TextField(
          controller: msgCon,
        ),
        contentPadding: EdgeInsets.fromLTRB(10, 0, 0, 0),
        trailing: Ink(
          decoration: const ShapeDecoration(
            color: Colors.lightGreen,
            shape: CircleBorder(),
          ),
          child: IconButton(
            iconSize: 30,
            icon: Icon(Icons.send),
            color: Colors.white,
            onPressed: (socket != null) ? submitMessage : null,
            padding: EdgeInsets.fromLTRB(3, 0, 0, 0.0),
          ),
        ),

        // IconButton(
        //   onPressed: (socket != null) ? submitMessage : null,
        //   //fillColor: Colors.green[200],
        //   icon: Icon(Icons.send, color: Colors.green),
        //   //
        //   //padding: EdgeInsets.fromLTRB(5, 0, 0, 0.0),
        //   //shape: CircleBorder(),
        // ),
      ),
    );
  }

  void connectToServer() async {
    print('conectando ...');
    _storeServerIP();
    alias = logincontroller.text;

    Socket.connect(ipCon.text, port, timeout: Duration(seconds: 5))
        .then((misocket) {
      setState(() {
        socket = misocket;
      });

      showSnackBarWithKey(
          "connected to ${socket.remoteAddress.address}:${socket.remotePort}");

      // Nos presentamos al servidor
      sendMsg('ALIAS', alias);

      socket.listen(
        (data) => onData(utf8.decode(data)),
        //(data) => onData(String.fromCharCodes(data).trim()),
        //(data) => onData(String(decoding: data,as: UTF8.self).trim()),
        onDone: onDone,
        onError: onError,
      );
    }).catchError((e) {
      showSnackBarWithKey(e.toString());
    });
  }

  void onData(data) {
    LineSplitter ls = new LineSplitter();
    List<String> lines = ls.convert(data);
    lines.forEach(onLine);
  }

  void onLine(line) {
    print('onData: $line');
    setState(() {
      Map msg = jsonDecode(line);

      switch (msg["action"]) {
        case 'ID':
          meId = int.parse(msg["value"]);
          break;
        case 'USERS':
          items.insert(
              0,
              MessageItem(
                0,
                'USERS',
                msg["value"],
              ));
          var list = jsonDecode(msg["value"]);
          list.forEach((u) => users[u['id']] = u['alias']);
          break;
        case 'ALIAS':
          users[msg['from']] = msg['value'];
          break;
        case 'QUIT':
          users.remove(msg['from']);
          break;
        default:
          items.insert(
              0, MessageItem(msg['from'], msg['action'], msg['value']));

          break;
      }
    });
  }

  void onDone() {
    showSnackBarWithKey("Connection has terminated.");
    disconnectFromServer();
  }

  void onError(e) {
    print("onError: $e");
    showSnackBarWithKey(e.toString());
    disconnectFromServer();
  }

  void disconnectFromServer() {
    meId = 0;
    sendMsg('QUIT', '');
    print("disconnectFromServer");

    socket.close();
    setState(() {
      socket = null;
    });
  }

  void sendMsg(String action, dynamic value, [Map data = const {}]) {
    var msg = Map();
    msg["action"] = action;
    msg["value"] = value.toString();
    msg.addAll(data);

    socket?.write('${jsonEncode(msg)}');
  }

  void _storeServerIP() async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    sp.setString("serverIP", ipCon.text);
  }

  void _loadServerIP() async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    setState(() {
      ipCon.text = sp.getString("serverIP");
    });
  }

  void submitMessage() {
    if (msgCon.text.isEmpty) return;
    var msg = msgCon.text;
    msgCon.clear();

    var action = 'MSG';
    if (msg.indexOf(':') > -1) {
      action = msg.split(':')[0].toUpperCase();
      msg = msg.split(':')[1];
    }

    if (msg.indexOf('@') > -1) {
      var data = msg.split('@')[0];
      var to = msg.split('@')[1]; //uno;dos;tres;cuatro
      sendMsg(action, data, {'to': to});
    } else
      sendMsg(action, msg);

    setState(() {
      items.insert(0, MessageItem(meId, action, msg));
    });
  }

  void showSnackBarWithKey(String message) {
    print(message);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Done',
          onPressed: () {},
        ),
      ),
    );
  }
}

class MessageItem {
  int owner;
  String type;
  String content;

  MessageItem(this.owner, this.type, this.content);
}
