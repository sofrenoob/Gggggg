import os
import subprocess

def run_command(command, capture_output=False):
    """
    Function to run shell commands and optionally capture output.
    """
    result = subprocess.run(command, shell=True, capture_output=capture_output, text=True)
    return result.stdout if capture_output else None

def install_openvpn():
    """
    Installs OpenVPN and sets up the server configuration.
    """
    print("Atualizando pacotes do sistema...")
    run_command("sudo apt update && sudo apt upgrade -y")
    
    print("Instalando o OpenVPN e Easy-RSA...")
    run_command("sudo apt install -y openvpn easy-rsa")
    
    print("Criando e configurando a PKI...")
    run_command("make-cadir /etc/openvpn/easy-rsa")
    os.chdir("/etc/openvpn/easy-rsa")
    run_command("./easyrsa init-pki")
    run_command("./easyrsa build-ca nopass")
    run_command("./easyrsa gen-req server nopass")
    run_command("echo 'yes' | ./easyrsa sign-req server server")
    run_command("./easyrsa gen-dh")
    run_command("./easyrsa gen-crl")
    
    print("Copiando certificados e chaves para o diretório do OpenVPN...")
    run_command("sudo cp pki/ca.crt pki/private/server.key pki/issued/server.crt pki/dh.pem /etc/openvpn")
    
    print("Criando arquivo de configuração do servidor OpenVPN...")
    server_config = """
port 1194
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
cipher AES-256-CBC
user nobody
group nogroup
persist-key
persist-tun
status openvpn-status.log
log-append /var/log/openvpn.log
verb 3
    """
    with open("/etc/openvpn/server.conf", "w") as f:
        f.write(server_config)
    
    print("Habilitando roteamento de IP...")
    run_command("sudo sysctl -w net.ipv4.ip_forward=1")
    run_command("echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf")
    
    print("Configurando regras de firewall...")
    run_command("sudo iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE")
    run_command("sudo iptables-save | sudo tee /etc/iptables.rules")
    
    firewall_script = """
#!/bin/sh
iptables-restore < /etc/iptables.rules
    """
    with open("/etc/network/if-up.d/iptables", "w") as f:
        f.write(firewall_script)
    run_command("sudo chmod +x /etc/network/if-up.d/iptables")
    
    print("Iniciando o serviço OpenVPN...")
    run_command("sudo systemctl start openvpn@server")
    run_command("sudo systemctl enable openvpn@server")
    print("OpenVPN instalado e configurado com sucesso!")

def configure_proxy_websocket():
    """
    Configures OpenVPN to work with a WebSocket proxy.
    """
    print("Configurando WebSocket Proxy para OpenVPN...")

    # Instalação do WebSocket Proxy (usando WebSocketd como exemplo)
    print("Instalando websocketd...")
    run_command("sudo apt install -y websocketd")

    # Permitir que o usuário escolha a porta do WebSocket
    websocket_port = input("Digite a porta para o WebSocket Proxy (default: 8080): ") or "8080"

    # Criar um script simples para redirecionar tráfego do WebSocket para o OpenVPN
    print("Criando script de redirecionamento do WebSocket...")
    websocket_script = f"""
#!/bin/bash
socat -T15 -d -d TCP4-LISTEN:{websocket_port},reuseaddr,fork TCP4:127.0.0.1:1194
    """
    with open("/usr/local/bin/websocket-vpn.sh", "w") as f:
        f.write(websocket_script)
    run_command("chmod +x /usr/local/bin/websocket-vpn.sh")

    # Criar um serviço systemd para o WebSocket Proxy
    print("Criando serviço systemd para websocketd...")
    websocket_service = f"""
[Unit]
Description=WebSocket Proxy for OpenVPN
After=network.target

[Service]
ExecStart=/usr/bin/websocketd --port={websocket_port} --staticdir=/usr/local/bin/ /usr/local/bin/websocket-vpn.sh
Restart=always
User=nobody
Group=nogroup

[Install]
WantedBy=multi-user.target
    """
    with open("/etc/systemd/system/websocket-vpn.service", "w") as f:
        f.write(websocket_service)

    # Iniciar e habilitar o serviço
    print("Iniciando o serviço WebSocket Proxy...")
    run_command("sudo systemctl daemon-reload")
    run_command("sudo systemctl enable websocket-vpn")
    run_command("sudo systemctl start websocket-vpn")

    print(f"Proxy WebSocket configurado com sucesso na porta {websocket_port}!")
    print("Certifique-se de configurar o cliente para usar o WebSocket na mesma porta.")

def main_menu():
    """
    Main menu for the program.
    """
    while True:
        print("\n=== Menu de Configuração OpenVPN ===")
        print("1. Instalar e configurar OpenVPN")
        print("2. Configurar Proxy no OpenVPN")
        print("3. Configurar SSL Tunnel")
        print("4. Configurar Proxy WebSocket")
        print("5. Sair")
        
        choice = input("Escolha uma opção: ")
        if choice == "1":
            install_openvpn()
        elif choice == "2":
            configure_proxy()
        elif choice == "3":
            configure_ssl_tunnel()
        elif choice == "4":
            configure_proxy_websocket()
        elif choice == "5":
            print("Saindo...")
            break
        else:
            print("Opção inválida. Tente novamente.")

if __name__ == "__main__":
    main_menu()