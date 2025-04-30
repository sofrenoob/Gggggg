import subprocess
import os
import platform
import psutil
import time

# Função para exibir o status do sistema
def system_status():
    print("\n===== STATUS DO SISTEMA =====")
    uname = platform.uname()
    memory = psutil.virtual_memory()
    cpu = psutil.cpu_percent(interval=1)
    
    print(f"OS: {uname.system} {uname.release}")
    print(f"Memória RAM: Total: {memory.total / 1024**2:.2f} MB | Em uso: {memory.percent}%")
    print(f"Processador: Núcleos: {psutil.cpu_count(logical=False)} | Em uso: {cpu}%")
    print(f"Hora atual: {time.strftime('%H:%M:%S')}")

# Função para abrir portas TCP
def open_tcp_port(port):
    subprocess.run(f"sudo ufw allow {port}/tcp", shell=True)
    print(f"Porta TCP {port} aberta com sucesso!")
    subprocess.run("sudo ufw status", shell=True)

# Função para fechar portas TCP
def close_tcp_port(port):
    subprocess.run(f"sudo ufw deny {port}/tcp", shell=True)
    print(f"Porta TCP {port} fechada com sucesso!")
    subprocess.run("sudo ufw status", shell=True)

# Função para visualizar portas abertas
def view_open_tcp_ports():
    subprocess.run("sudo ufw status", shell=True)

# Função para gerenciar DNS
def manage_dns():
    print("\nGerenciando DNS...")
    print("Escolha o servidor DNS:")
    print("1. Google DNS (8.8.8.8)")
    print("2. Cloudflare DNS (1.1.1.1)")
    print("3. Voltar")
    
    choice = input("Escolha uma opção: ")
    
    if choice == "1":
        subprocess.run("sudo systemd-resolve --set-dns=8.8.8.8", shell=True)
        print("DNS alterado para Google DNS (8.8.8.8)")
    elif choice == "2":
        subprocess.run("sudo systemd-resolve --set-dns=1.1.1.1", shell=True)
        print("DNS alterado para Cloudflare DNS (1.1.1.1)")
    elif choice == "3":
        return
    else:
        print("Opção inválida, tente novamente.")

# Função para gerenciar IPv6 e IPv4
def manage_ip_version():
    print("\nGerenciando IPv6 e IPv4...")
    print("1. Ativar IPv6")
    print("2. Desativar IPv6")
    print("3. Ativar IPv4")
    print("4. Desativar IPv4")
    print("5. Voltar")
    
    choice = input("Escolha uma opção: ")
    
    if choice == "1":
        subprocess.run("sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0", shell=True)
        print("IPv6 ativado!")
    elif choice == "2":
        subprocess.run("sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1", shell=True)
        print("IPv6 desativado!")
    elif choice == "3":
        subprocess.run("sudo sysctl -w net.ipv4.conf.all.disable_ipv4=0", shell=True)
        print("IPv4 ativado!")
    elif choice == "4":
        subprocess.run("sudo sysctl -w net.ipv4.conf.all.disable_ipv4=1", shell=True)
        print("IPv4 desativado!")
    elif choice == "5":
        return
    else:
        print("Opção inválida, tente novamente.")

# Função para limpar cache e arquivos desnecessários
def clean_cache():
    print("\nLimpando cache e arquivos desnecessários...")
    subprocess.run("sudo apt-get clean", shell=True)
    subprocess.run("sudo apt-get autoremove -y", shell=True)
    subprocess.run("sudo apt-get autoclean", shell=True)
    print("Cache e arquivos desnecessários removidos.")

# Função para gerenciar usuários
def manage_users():
    while True:
        print("\n===== GERENCIAMENTO DE USUÁRIOS =====")
        print("1. Adicionar usuário")
        print("2. Ver usuários online")
        print("3. Alterar senha de usuário")
        print("4. Alterar data de expiração do usuário")
        print("5. Limite de conexões do usuário")
        print("6. Voltar")
        
        choice = input("Escolha uma opção: ")
        
        if choice == "1":
            username = input("Nome de usuário: ")
            password = input("Senha do usuário: ")
            subprocess.run(f"sudo adduser {username}", shell=True)
            subprocess.run(f"echo '{username}:{password}' | sudo chpasswd", shell=True)
            print(f"Usuário {username} adicionado com sucesso!")
        elif choice == "2":
            subprocess.run("who", shell=True)
        elif choice == "3":
            username = input("Nome de usuário: ")
            new_password = input("Nova senha: ")
            subprocess.run(f"echo '{username}:{new_password}' | sudo chpasswd", shell=True)
            print(f"Senha do usuário {username} alterada com sucesso!")
        elif choice == "4":
            username = input("Nome de usuário: ")
            expiration_date = input("Data de expiração (YYYY-MM-DD): ")
            subprocess.run(f"sudo chage -E {expiration_date} {username}", shell=True)
            print(f"Data de expiração do usuário {username} alterada para {expiration_date}")
        elif choice == "5":
            username = input("Nome de usuário: ")
            limit = input("Limite de conexões (ex: 1 para permitir 1 conexão): ")
            subprocess.run(f"sudo usermod -aG {limit} {username}", shell=True)
            print(f"Limite de conexões para o usuário {username} alterado para {limit}")
        elif choice == "6":
            break
        else:
            print("Opção inválida, tente novamente.")

# Função para gerenciar conexões
def manage_connections():
    while True:
        print("\n===== GERENCIAMENTO DE CONEXÕES =====")
        print("1. Configurar Proxy WebSocket")
        print("2. Configurar V2Ray/Xray")
        print("3. Configurar UDP/Hysteria")
        print("4. Voltar")
        
        choice = input("Escolha uma opção: ")
        
        if choice == "1":
            print("Configuração de Proxy WebSocket")
        elif choice == "2":
            print("Configuração de V2Ray/Xray")
        elif choice == "3":
            print("Configuração de UDP/Hysteria")
        elif choice == "4":
            break
        else:
            print("Opção inválida, tente novamente.")

# Função para gerenciar firewall
def manage_firewall():
    while True:
        print("\n===== GERENCIAMENTO DE FIREWALL =====")
        print("1. Abrir porta TCP")
        print("2. Fechar porta TCP")
        print("3. Visualizar portas abertas")
        print("4. Voltar")
        
        choice = input("Escolha uma opção: ")
        
        if choice == "1":
            port = input("Digite o número da porta TCP a ser aberta: ")
            open_tcp_port(port)
        elif choice == "2":
            port = input("Digite o número da porta TCP a ser fechada: ")
            close_tcp_port(port)
        elif choice == "3":
            view_open_tcp_ports()
        elif choice == "4":
            break
        else:
            print("Opção inválida, tente novamente.")

# Função para exibir o menu principal
def main_menu():
    while True:
        print("\n===== MENU PRINCIPAL =====")
        print("1. Ver status do sistema")
        print("2. Gerenciar usuários")
        print("3. Gerenciar conexões")
        print("4. Gerenciar firewall")
        print("5. Gerenciar DNS")
        print("6. Gerenciar IPv6/IPv4")
        print("7. Limpar cache")
        print("8. Sair")
        
        choice = input("Escolha uma opção: ")
        
        if choice == "1":
            system_status()
        elif choice == "2":
            manage_users()
        elif choice == "3":
            manage_connections()
        elif choice == "4":
            manage_firewall()
        elif choice == "5":
            manage_dns()
        elif choice == "6":
            manage_ip_version()
        elif choice == "7":
            clean_cache()
        elif choice == "8":
            print("Saindo...")
            break
        else:
            print("Opção inválida, tente novamente.")

# Iniciar o menu principal
main_menu()
