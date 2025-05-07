import os
import sys
import requests
import socket
import ssl
from flask import Flask, request, jsonify
from threading import Thread

# Flask app for backend
app = Flask(__name__)

# Backend Endpoints
@app.route("/")
def index():
    return "Servidor Backend para Configuração de Proxy e SSL Tunnel"

@app.route("/install_dependencies", methods=["POST"])
def install_dependencies():
    try:
        os.system("sudo apt update && sudo apt install squid nginx stunnel4 -y")
        return jsonify({"status": "success", "message": "Dependências instaladas com sucesso!"})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)})

@app.route("/configure_squid", methods=["POST"])
def configure_squid():
    try:
        squid_conf = """
http_port 80
http_port 8080
http_port 443

acl localnet src all
http_access allow localnet
http_access deny all
"""
        with open("/etc/squid/squid.conf", "w") as f:
            f.write(squid_conf)
        os.system("sudo systemctl restart squid")
        return jsonify({"status": "success", "message": "Squid configurado e reiniciado com sucesso!"})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)})

@app.route("/configure_nginx", methods=["POST"])
def configure_nginx():
    try:
        nginx_conf = """
server {
    listen 80;
    listen 8080;
    listen 443 ssl;

    server_name localhost;

    location / {
        proxy_pass http://localhost:3000; # Substitua pelo endereço do seu app WebSocket
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }

    ssl_certificate /etc/ssl/certs/yourdomain.crt;
    ssl_certificate_key /etc/ssl/private/yourdomain.key;
}
"""
        with open("/etc/nginx/sites-available/default", "w") as f:
            f.write(nginx_conf)
        os.system("sudo systemctl restart nginx")
        return jsonify({"status": "success", "message": "Nginx configurado e reiniciado com sucesso!"})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)})

@app.route("/configure_stunnel", methods=["POST"])
def configure_stunnel():
    try:
        stunnel_conf = """
[https]
accept = 443
connect = 127.0.0.1:8080

[http]
accept = 80
connect = 127.0.0.1:8080
"""
        with open("/etc/stunnel/stunnel.conf", "w") as f:
            f.write(stunnel_conf)
        os.system("sudo systemctl enable stunnel4")
        os.system("sudo systemctl start stunnel4")
        return jsonify({"status": "success", "message": "Stunnel configurado e iniciado com sucesso!"})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)})

@app.route("/open_ports", methods=["POST"])
def open_ports():
    try:
        os.system("sudo ufw allow 80")
        os.system("sudo ufw allow 8080")
        os.system("sudo ufw allow 443")
        os.system("sudo ufw reload")
        return jsonify({"status": "success", "message": "Portas abertas com sucesso!"})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)})

@app.route("/send_payload", methods=["POST"])
def send_payload():
    try:
        data = request.json
        host = data.get("host", "127.0.0.1")
        port = int(data.get("port", 80))
        payload = data.get("payload", "")
        use_ssl = data.get("use_ssl", False)

        # Criar um socket
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

        # Envolver o socket em um túnel SSL, se necessário
        if use_ssl:
            context = ssl.create_default_context()
            sock = context.wrap_socket(sock, server_hostname=host)

        # Conectar ao servidor
        sock.connect((host, port))

        # Enviar a payload
        sock.sendall(payload.encode())

        # Receber a resposta
        response = sock.recv(4096)
        sock.close()

        return jsonify({"status": "success", "response": response.decode()})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)})


# Function to run the Flask app in a separate thread
def run_backend():
    app.run(host="0.0.0.0", port=5000)


# Menu Functions
def menu():
    while True:
        print("\nMenu de Configuração de Proxy e SSL Tunnel:")
        print("1. Instalar dependências")
        print("2. Configurar Squid Proxy")
        print("3. Configurar Nginx para WebSocket Proxy")
        print("4. Configurar SSL Tunnel (stunnel)")
        print("5. Abrir portas (80, 8080, 443)")
        print("6. Enviar payload personalizada")
        print("7. Sair")
        choice = input("Escolha uma opção: ")

        if choice == "1":
            response = requests.post("http://127.0.0.1:5000/install_dependencies")
            print(response.json()["message"])
        elif choice == "2":
            response = requests.post("http://127.0.0.1:5000/configure_squid")
            print(response.json()["message"])
        elif choice == "3":
            response = requests.post("http://127.0.0.1:5000/configure_nginx")
            print(response.json()["message"])
        elif choice == "4":
            response = requests.post("http://127.0.0.1:5000/configure_stunnel")
            print(response.json()["message"])
        elif choice == "5":
            response = requests.post("http://127.0.0.1:5000/open_ports")
            print(response.json()["message"])
        elif choice == "6":
            host = input("Digite o host do servidor: ")
            port = int(input("Digite a porta do servidor: "))
            use_ssl = input("Usar SSL? (s/n): ").lower() == "s"
            payload = input("Digite sua payload personalizada: ")
            response = requests.post("http://127.0.0.1:5000/send_payload", json={
                "host": host,
                "port": port,
                "payload": payload,
                "use_ssl": use_ssl
            })
            print(response.json())
        elif choice == "7":
            print("Saindo...")
            sys.exit(0)
        else:
            print("Opção inválida. Por favor, tente novamente.")


if __name__ == "__main__":
    # Start the backend in a separate thread
    backend_thread = Thread(target=run_backend)
    backend_thread.daemon = True
    backend_thread.start()

    # Start the menu
    menu()