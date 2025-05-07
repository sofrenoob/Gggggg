import os
import subprocess
import sys

def install_dependencies():
    print("Instalando dependências necessárias...")
    os.system("sudo apt update")
    os.system("sudo apt install squid nginx stunnel4 -y")
    print("Dependências instaladas com sucesso!")

def configure_squid():
    print("Configurando o Squid Proxy...")
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
    print("Squid configurado e reiniciado com sucesso!")

def configure_nginx():
    print("Configurando o Nginx para Proxy WebSocket...")
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
    print("Nginx configurado e reiniciado com sucesso!")

def configure_stunnel():
    print("Configurando o SSL Tunnel (stunnel)...")
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
    print("Stunnel configurado e iniciado com sucesso!")

def open_ports():
    print("Abrindo portas 80, 8080 e 443 no firewall...")
    os.system("sudo ufw allow 80")
    os.system("sudo ufw allow 8080")
    os.system("sudo ufw allow 443")
    os.system("sudo ufw reload")
    print("Portas abertas com sucesso!")

def menu():
    while True:
        print("\nMenu de Configuração de Proxy e SSL Tunnel:")
        print("1. Instalar dependências")
        print("2. Configurar Squid Proxy")
        print("3. Configurar Nginx para WebSocket Proxy")
        print("4. Configurar SSL Tunnel (stunnel)")
        print("5. Abrir portas (80, 8080, 443)")
        print("6. Sair")
        choice = input("Escolha uma opção: ")

        if choice == "1":
            install_dependencies()
        elif choice == "2":
            configure_squid()
        elif choice == "3":
            configure_nginx()
        elif choice == "4":
            configure_stunnel()
        elif choice == "5":
            open_ports()
        elif choice == "6":
            print("Saindo...")
            sys.exit(0)
        else:
            print("Opção inválida. Por favor, tente novamente.")

if __name__ == "__main__":
    menu()