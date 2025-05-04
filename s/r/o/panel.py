import os
import sys
import json
import socket
from http.server import HTTPServer, SimpleHTTPRequestHandler
import asyncio
import websockets
from ssl import SSLContext, PROTOCOL_TLS_SERVER
import threading

CONFIG_FILE = "config.json"

def clear_console():
    """
    Limpa o terminal para melhorar a apresentação.
    """
    os.system('cls' if os.name == 'nt' else 'clear')

def display_panel():
    """
    Exibe o menu principal do painel gerenciador.
    """
    clear_console()
    print("\033[1;37;44m")  # Fundo azul, texto branco
    print("+" + "-" * 50 + "+")
    print("|{:^50}|".format(" SUPER PROXY TOOL "))
    print("+" + "-" * 50 + "+")
    print("\033[0m")  # Resetar cores

    print("Escolha uma opção:")
    print("1. Iniciar Proxy HTTP/HTTPS")
    print("2. Iniciar Proxy WebSocket")
    print("3. Iniciar Reverse Proxy")
    print("4. Alterar Portas")
    print("5. Visualizar Portas")
    print("6. Ver Status do Sistema")
    print("7. Criar Arquivos do Sistema")
    print("8. Sair")

def load_config():
    """
    Carrega as configurações do arquivo JSON. Se o arquivo não existir, cria um padrão.
    """
    if not os.path.exists(CONFIG_FILE):
        default_config = {
            "http_proxy_port": 8080,
            "websocket_proxy_port": 8081,
            "reverse_proxy_port": 8082,
            "tls_proxy_port": 8083
        }
        save_config(default_config)
        return default_config

    with open(CONFIG_FILE, "r") as file:
        return json.load(file)

def save_config(config):
    """
    Salva as configurações no arquivo JSON.
    """
    with open(CONFIG_FILE, "w") as file:
        json.dump(config, file, indent=4)

def update_port(service_name, new_port):
    """
    Atualiza a porta de um serviço específico.

    :param service_name: Nome do serviço (ex.: http_proxy_port, websocket_proxy_port).
    :param new_port: Nova porta para o serviço.
    """
    config = load_config()
    if service_name in config:
        config[service_name] = new_port
        save_config(config)
        print(f"[INFO] Porta para '{service_name}' atualizada para {new_port}.")
    else:
        print(f"[ERRO] Serviço '{service_name}' não encontrado nas configurações.")

def check_port_in_use(port):
    """
    Verifica se uma porta está em uso.

    :param port: Porta a ser verificada.
    :return: True se a porta estiver em uso, False caso contrário.
    """
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex(('localhost', port)) == 0

def view_ports():
    """
    Exibe as portas configuradas para os serviços.
    """
    config = load_config()
    print("\nPortas Configuradas:")
    print("+----------------------+-------+")
    print("| Serviço              | Porta |")
    print("+----------------------+-------+")
    for service, port in config.items():
        print(f"| {service:<20} | {port:<5} |")
    print("+----------------------+-------+\n")

def system_status():
    """
    Coleta o status do sistema, incluindo o estado dos serviços e conectividade com a internet.
    """
    config = load_config()
    status = {}

    print("\n[INFO] Checando status do sistema...\n")
    for service, port in config.items():
        in_use = check_port_in_use(port)
        status[service] = {
            "port": port,
            "status": "Rodando" if in_use else "Parado"
        }

    # Verificar conectividade com a internet
    try:
        socket.create_connection(("8.8.8.8", 53), timeout=3)
        internet_status = "Conectado"
    except socket.error:
        internet_status = "Desconectado"

    # Mostrar status
    print("+----------------------+-------+------------+")
    print("| Serviço              | Porta | Status     |")
    print("+----------------------+-------+------------+")
    for service, info in status.items():
        print(f"| {service:<20} | {info['port']:<5} | {info['status']:<10} |")
    print("+----------------------+-------+------------+")
    print(f"\nConectividade com a Internet: {internet_status}\n")

def change_ports():
    """
    Menu para alterar as portas dos serviços.
    """
    config = load_config()
    print("\nPortas Atuais:")
    for service, port in config.items():
        print(f"- {service}: {port}")

    print("\nServiços disponíveis para alteração:")
    print("1. Proxy HTTP/HTTPS")
    print("2. Proxy WebSocket")
    print("3. Reverse Proxy")
    print("4. Proxy TLS\n")
    choice = input("Escolha o serviço (1-4): ")

    service_map = {
        "1": "http_proxy_port",
        "2": "websocket_proxy_port",
        "3": "reverse_proxy_port",
        "4": "tls_proxy_port"
    }

    if choice in service_map:
        service_name = service_map[choice]
        try:
            new_port = int(input(f"Digite a nova porta para {service_name}: "))
            if 1 <= new_port <= 65535:
                update_port(service_name, new_port)
            else:
                print("[ERRO] Porta inválida. Escolha um valor entre 1 e 65535.")
        except ValueError:
            print("[ERRO] Entrada inválida. Certifique-se de digitar um número.")
    else:
        print("[ERRO] Escolha inválida. Tente novamente.")

def start_http_proxy():
    """
    Inicia um servidor HTTP básico para funcionar como proxy.
    """
    config = load_config()
    port = config["http_proxy_port"]

    class ProxyHTTPRequestHandler(SimpleHTTPRequestHandler):
        def do_GET(self):
            print(f"[INFO] Proxy HTTP: Requisição para {self.path}")
            super().do_GET()

    server = HTTPServer(('0.0.0.0', port), ProxyHTTPRequestHandler)
    print(f"[INFO] Proxy HTTP rodando na porta {port}...")
    server.serve_forever()

def start_websocket_proxy():
    """
    Inicia um servidor WebSocket.
    """
    config = load_config()
    port = config["websocket_proxy_port"]

    async def websocket_handler(websocket, path):
        print(f"[INFO] WebSocket conectado: {path}")
        try:
            async for message in websocket:
                print(f"[INFO] Mensagem recebida: {message}")
                await websocket.send(f"Echo: {message}")
        except websockets.exceptions.ConnectionClosed as e:
            print(f"[INFO] Conexão WebSocket encerrada: {e}")

    print(f"[INFO] WebSocket Proxy rodando na porta {port}...")
    asyncio.get_event_loop().run_until_complete(
        websockets.serve(websocket_handler, "0.0.0.0", port)
    )
    asyncio.get_event_loop().run_forever()

def start_reverse_proxy():
    """
    Exemplo de reverse proxy.
    """
    config = load_config()
    port = config["reverse_proxy_port"]

    class ReverseProxyHandler(SimpleHTTPRequestHandler):
        def do_GET(self):
            print(f"[INFO] Reverse Proxy: Requisição para {self.path}")
            super().do_GET()

    server = HTTPServer(('0.0.0.0', port), ReverseProxyHandler)
    print(f"[INFO] Reverse Proxy rodando na porta {port}...")
    server.serve_forever()

def create_required_files():
    """
    Cria os arquivos necessários do sistema.
    """
    print("[INFO] Criando arquivos necessários...")
    load_config()  # Gera o arquivo config.json se necessário
    print("[INFO] Arquivos criados com sucesso!")

def main():
    """
    Loop principal do painel gerenciador.
    """
    while True:
        display_panel()
        choice = input("\nDigite sua opção: ")

        if choice == "1":
            threading.Thread(target=start_http_proxy).start()
        elif choice == "2":
            threading.Thread(target=start_websocket_proxy).start()
        elif choice == "3":
            threading.Thread(target=start_reverse_proxy).start()
        elif choice == "4":
            print("\nAlterar Portas...")
            change_ports()
        elif choice == "5":
            print("\nVisualizando Portas Configuradas...\n")
            view_ports()
        elif choice == "6":
            print("\nVerificando Status do Sistema...\n")
            system_status()
        elif choice == "7":
            print("\nCriando Arquivos do Sistema...")
            create_required_files()
        elif choice == "8":
            print("\nSaindo do painel...")
            sys.exit(0)
        else:
            print("\nOpção inválida. Tente novamente.")

if __name__ == "__main__":
    main()