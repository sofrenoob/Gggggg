import socket
import threading
import ssl

class Proxy:
    def __init__(self, config):
        self.config = config
        self.server_socket = None

    def start(self):
        """Inicia o servidor proxy."""
        try:
            self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.server_socket.bind((self.config.host, self.config.port))
            self.server_socket.listen(5)
            print(f"Proxy iniciado em {self.config.host}:{self.config.port}")
            self.accept_connections()
        except Exception as e:
            print(f"Erro ao iniciar o proxy: {e}")

    def accept_connections(self):
        """Aceita conexões de clientes."""
        while True:
            client_socket, client_address = self.server_socket.accept()
            print(f"Conexão recebida de {client_address}")
            threading.Thread(target=self.handle_client, args=(client_socket,)).start()

    def handle_client(self, client_socket):
        """Manipula a conexão do cliente."""
        try:
            request = client_socket.recv(4096)
            print(f"Requisição recebida: {request.decode('utf-8')}")

            # Conecta ao servidor de destino
            server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            server_socket.connect((self.config.remote_host, self.config.remote_port))

            # Encaminha a requisição do cliente para o servidor
            server_socket.send(request)

            # Recebe a resposta do servidor e encaminha de volta ao cliente
            response = server_socket.recv(4096)
            client_socket.send(response)

            # Fecha os sockets
            server_socket.close()
            client_socket.close()
        except Exception as e:
            print(f"Erro ao manipular cliente: {e}")

class ProxyConfig:
    def __init__(self, host='127.0.0.1', port=8888, remote_host='example.com', remote_port=80, intercept_tls=False, dns_over_https=False):
        self.host = host
        self.port = port
        self.remote_host = remote_host
        self.remote_port = remote_port
        self.intercept_tls = intercept_tls
        self.dns_over_https = dns_over_https

        if self.intercept_tls:
            self.context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
            self.context.load_cert_chain(certfile="server.crt", keyfile="server.key")

    def configure_tls(self):
        """Configura interceptação TLS."""
        if not self.intercept_tls:
            return None
        print("Interceptação TLS ativada.")
        return self.context