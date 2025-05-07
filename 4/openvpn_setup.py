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

def configure_proxy():
    """
    Configures OpenVPN client to use a proxy.
    """
    proxy_ip = input("Informe o IP do proxy: ")
    proxy_port = input("Informe a porta do proxy: ")
    proxy_user = input("Informe o usuário do proxy (ou deixe vazio): ")
    proxy_pass = input("Informe a senha do proxy (ou deixe vazio): ")

    proxy_config = f"http-proxy {proxy_ip} {proxy_port}"
    if proxy_user and proxy_pass:
        proxy_config += f" {proxy_user} {proxy_pass}"

    print("\nAdicione a seguinte linha ao arquivo .ovpn do cliente:")
    print(proxy_config)

def configure_ssl_tunnel():
    """
    Configures SSL Tunnel with Stunnel.
    """
    print("Instalando e configurando Stunnel...")
    run_command("sudo apt install -y stunnel4")
    
    print("Gerando certificado SSL...")
    run_command("openssl req -new -x509 -days 365 -nodes -out /etc/stunnel/stunnel.pem -keyout /etc/stunnel/stunnel.pem")
    run_command("chmod 600 /etc/stunnel/stunnel.pem")
    
    print("Criando configuração do Stunnel...")
    stunnel_config = """
[openvpn]
accept = 443
connect = 127.0.0.1:1194
cert = /etc/stunnel/stunnel.pem
    """
    with open("/etc/stunnel/stunnel.conf", "w") as f:
        f.write(stunnel_config)
    
    print("Iniciando Stunnel...")
    run_command("systemctl enable stunnel4")
    run_command("systemctl start stunnel4")
    print("SSL Tunnel configurado com sucesso!")

def main_menu():
    """
    Main menu for the program.
    """
    while True:
        print("\n=== Menu de Configuração OpenVPN ===")
        print("1. Instalar e configurar OpenVPN")
        print("2. Configurar Proxy no OpenVPN")
        print("3. Configurar SSL Tunnel")
        print("4. Sair")
        
        choice = input("Escolha uma opção: ")
        if choice == "1":
            install_openvpn()
        elif choice == "2":
            configure_proxy()
        elif choice == "3":
            configure_ssl_tunnel()
        elif choice == "4":
            print("Saindo...")
            break
        else:
            print("Opção inválida. Tente novamente.")

if __name__ == "__main__":
    main_menu()