Ejemplo de Cliente Y Servidor socket 

Tambien hay un cliente Flutter en
https://github.com/srlopez/socketcliapp.git



1.- Arrancar el servidor
   $ dart socket_server2.dart
Se arranca en la IP 127.0.0.1
Si quieres arrancarlo en otra IP indica el intermace en la linea de comando
   $ dart sokect_server2.dart {interafce/wlo1/Ethernet}

2.- Arrancar el cliente
   $ dart scocket_client2.dart {user_alias:dummy} {IPServer:127.0.0.1}

   Si se omite IPServer se conecta a Looback
   Si se omite alias se asigna 'dummy'

En el cliente se puede introducir un mensaje por la consola
'quit' sale del cliente

mshsdvsd@alias;pepe manda el mensaje a los alias exclusivamente. Pudene ser varios separados por ;

