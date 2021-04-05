Ejemplo de Cliente Y Servidor socket 

Tambien hay un cliente Flutter en
https://github.com/srlopez/socketcliapp.git



1.- Arrancar el servidor
   $ dart socket_server.dart
Se arranca en la IP 127.0.0.1
Si quieres arrancarlo en otra IP indica el intermace en la linea de comando
   $ dart sokect_server.dart {interafce/wlo1/Ethernet}

2.- Arrancar el cliente
   $ dart socket_client.dart {user_alias:dummy} {IPServer:127.0.0.1}

   Si se omite IPServer se conecta a Looback
   Si se omite alias se asigna 'hostname'


En el cliente se puede introducir un mensaje por la consola
'quit' sale del cliente

Ejemplos de mansajes standard:
`un unico texto`  <- MSG noraml a todos los clientes, se envía: `{"action":"MSG","value":"un unico texto"}`
`o un texto a destinatarios@alias;pepe`   <- MSG a unos destinatarios concretos sepàrados por `;`, se envía: `{"action":"MSG","value":"o un texto a destinatarios","to":"alias;pepe"}`
`temp:45`  <- mensaje TEMP con valor 45 a todos, se envía: `{"action":"TEMP","value":"45"}`
`latlng:-3.45675, 6.976343` <- menasje LATLNG, se envía: `{"action":"LATLNG","value":"-3.45675, 6.976343"}`
 
El cliente recibe estos mensajes del servidor:
`ID` -> indica el identificador asignado `{action: ID, value: 377229716, from: 377229716, on: 2021-04-05 11:16:08}`
`USERS` -> la lista de usuarios conectados al servidor `{action: USERS, value: [ {"id":305760806,"alias":"slimbook"}, {"id":377229716,"alias":"slimbook23"}, {"id":196934675,"alias":"slimbook96"} ], from: 196934675, on: 2021-04-05 11:16:10}`

y estos mensajes especificos de los clientes:
`ALIAS` cuando un cliente se identifica, se recibe: `{action: ALIAS, value: slimbook96, from: 196934675, on: 2021-04-05 11:16:10}`
`LATLNG`, cuando cambia de ubicacion, se recibe: `{action: LATLNG, value: -3.6709234, 6.864667, from: 305760806, on: 2021-04-05 11:41:53}`
`QUIT` cuando se sale, se recibe: `{action: QUIT, value: 305760806, from: 305760806, on: 2021-04-05 11:42:42}`


El cliente debe enviar un mensaje `ALIAS` para indicar una identificación facil: `{"action":"ALIAS","value":"Pedro"}` 


```diff
- Los mensajes son en formato JSON
- cada mensaje JSON se envia un '\n'
- si se quiere enviar un salto de linea '\n' en el valor de un mensaje, se debe acordar una sustitución y su conversion a '\n' entre los clientes
```