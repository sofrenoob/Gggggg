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

def create_client_config():
    """
    Creates a client configuration file and outputs it to the terminal.
    """
    print("Gerando configuração para cliente...")
    os.chdir("/etc/openvpn/easy-rsa")
    run_command("./easyrsa gen-req client nopass")
    run_command("echo 'yes' | ./easyrsa sign-req client client")
    run_command("mkdir -p /etc/openvpn/client-configs/files")
    run_command("cp pki/ca.crt pki/issued/client.crt pki/private/client.key /etc/openvpn/client-configs/files/")
    
    client_config = """
client
dev tun
proto udp
remote <SERVER_IP> 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-CBC
auth SHA256
key-direction 1
verb 3
<ca>
{ca_cert}
</ca>
<cert>
{client_cert}
</cert>
<key>
{client_key}
</key>
    """
    with open("/etc/openvpn/client-configs/files/ca.crt", "r") as f:
        ca_cert = f.read()
    with open("/etc/openvpn/client-configs/files/client.crt", "r") as f:
        client_cert = f.read()
    with open("/etc/openvpn/client-configs/files/client.key", "r") as f:
        client_key = f.read()
    
    client_config = client_config.format(ca_cert=ca_cert, client_cert=client_cert, client_key=client_key)
    client_config_path = "/etc/openvpn/client-configs/client.ovpn"
    with open(client_config_path, "w") as f:
        f.write(client_config)
    
    print(f"Arquivo de configuração do cliente criado em: {client_config_path}")
    print("\n=== Conteúdo do arquivo de configuração do cliente ===")
    print(client_config)

def main_menu():
    """
    Main menu for the program.
    """
    while True:
        print("\n=== Menu de Configuração OpenVPN ===")
        print("1. Instalar e configurar OpenVPN")
        print("2. Gerar arquivo de configuração do cliente")
        print("3. Sair")
        
        choice = input("Escolha uma opção: ")
        if choice == "1":
            install_openvpn()
        elif choice == "2":
            create_client_config()
        elif choice == "3":
            print("Saindo...")
            break
        else:
            print("Opção inválida. Tente novamente.")

if __name__ == "__main__":
    main_menu()