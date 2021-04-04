var net = require('net');

var client = new net.Socket()

//conexion cliente
port=7654;
ip = '127.0.0.1' 
client.connect(port, ip, function() {
    console.log('Conectado');
    client.write('{ "action":"ALIAS", "value":"SOKETJS" }')
});
client.on("data", (data) => {
    console.log(data.toString());
});
client.on('end', () => {
    console.log('disconnected from server');
});
