# socketFlutterDart

Testing sockets in Dart and Flutter  

## dartCliServer/server.dart

Console application that performs the socket server role. When starting it shows the available interfaces.  

run: `dart server.dart {interface}`  
example:  
- `dart server.dart` to run in loopback  
- `dart server.dart Ethernet` to run on the local network  
- etc...  

## dartCliServer/client.dart

Sockets client console application.
Through the console you can enter messages to send to the different clients
They can be run with as many clients as desired  

run: `dart client.dart {nickname} {IPServer}`  
example:  
- `dart client.dart` to loopback with aliases` dummy`  
- `dart client.dart Jhon 10.10.12.198` to run on the local network, with aliases Jhon  

The messages that are received are shown, and you can also send a message by typing in the console. Examples of messages can be:  
- `A normal text`  
- `a text addressed to someone@Jhon`  
- `messages@Jhon; Martin`  


## flutterCli/main.dart

Flutter scoket client that connects to the previous server.

When starting, the nickname and IP of the server to connect is requested.
If the server is local, the Android emulator documentation indicates that it redirects from 10.0.2.2

====== ===== ===== ===== ====

Testeando sockets en Dart y Flutter

## dartCliServer/server.dart

Aplicación de consola que realiza la función de servidor de sockets. Al arrancarlo muestra las interfaces disponibles.  

run:  `dart server.dart {interface}`  
ejemplo:
- `dart server.dart` para correr en loopback
- `dart server.dart Ethernet` para correr en la red local
- etc...
      
## dartCliServer/client.dart

Aplicación de consola cliente sockets. 
Mediante la consola se pueden introducir mensajes a enviar a los distintos clientes
Se pueden poner a correr con tantos clientes como se desee  

run:  `dart client.dart {nickname} {IPServer}`  
ejemplo:
- `dart client.dart` para correr en loopback con alias `dummy`
- `dart client.dart Jhon 10.10.12.198` para correr en la red local, con alias Jhon

Se muestran los mensjaes que se reciben, y tambien puedes enviar un mensaje escribiendo en la consola. Ejemplos de mensaje puede ser:  
- `Un texto normal`  
- `un texto dirigido a alguien@Jhon`   
- `mensajes@Jhon;Martin`   

## flutterCli/main.dart

Cliente Flutter scoket que se conecta al anterior servidor

Al iniciarse se pide el nickname y la IP del servidor a conectarse.
Si el servidor es local la documentación del emulador de Android indica que se redirige desde 10.0.2.2
