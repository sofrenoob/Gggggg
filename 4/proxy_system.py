#!/usr/bin/env python3
import os
import sys
import json
import asyncio
import websockets
import paramiko
import datetime
import psutil
import threading
from simple_term_menu import TerminalMenu
from datetime import datetime, timedelta

class ProxyConfig:
    def __init__(self):
        self.config = {
            'ports': {},
            'users': {},
            'protocols': ['ws', 'wss', 'ssh', 'http', 'https'],
            'backend_rules': {}
        }
        self.config_file = 'proxy_config.json'
        self.load_config()

    def load_config(self):
        if os.path.exists(self.config_file):
            with open(self.config_file, 'r') as f:
                self.config = json.load(f)

    def save_config(self):
        with open(self.config_file, 'w') as f:
            json.dump(self.config, f, indent=4)

class SSHManager:
    def __init__(self):
        self.ssh_config_path = '/etc/ssh/sshd_config'

    def add_user(self, username, password, expire_date=None, bandwidth_limit=None):
        try:
            # Criar usuário
            os.system(f'useradd -m {username}')
            os.system(f'echo "{username}:{password}" | chpasswd')

            # Configurar data de expiração
            if expire_date:
                os.system(f'chage -E {expire_date} {username}')

            # Configurar limite de banda
            if bandwidth_limit:
                self.set_bandwidth_limit(username, bandwidth_limit)

            return True
        except Exception as e:
            print(f"Erro ao adicionar usuário: {e}")
            return False

    def set_bandwidth_limit(self, username, limit):
        # Implementar limitação de banda usando tc
        os.system(f'tc qdisc add dev eth0 root handle 1: htb default 10')
        os.system(f'tc class add dev eth0 parent 1: classid 1:{username} htb rate {limit}kbit')

class ProxyServer:
    def __init__(self, config):
        self.config = config
        self.connections = {}
        self.backend_servers = {}

    async def start_proxy(self, port):
        async def proxy_handler(websocket, path):
            client_address = websocket.remote_address
            print(f"Nova conexão de {client_address}")

            try:
                # Identificar protocolo
                protocol = await websocket.recv()
                if protocol not in self.config.config['protocols']:
                    await websocket.close()
                    return

                # Aplicar regras de backend
                backend = self.get_backend_server(protocol, client_address)
                
                # Estabelecer conexão com backend
                async with websockets.connect(backend) as backend_ws:
                    await self.handle_bidirectional_proxy(websocket, backend_ws)

            except Exception as e:
                print(f"Erro no proxy: {e}")
                await websocket.close()

        server = await websockets.serve(proxy_handler, "0.0.0.0", port)
        print(f"Proxy iniciado na porta {port}")
        await server.wait_closed()

    def get_backend_server(self, protocol, client_address):
        rules = self.config.config['backend_rules']
        # Implementar lógica de seleção de backend baseada em regras
        return rules.get(protocol, "ws://localhost:8080")

    async def handle_bidirectional_proxy(self, client_ws, backend_ws):
        async def forward(source, destination):
            try:
                async for message in source:
                    await destination.send(message)
            except Exception:
                pass

        await asyncio.gather(
            forward(client_ws, backend_ws),
            forward(backend_ws, client_ws)
        )

class MenuInterface:
    def __init__(self):
        self.proxy_config = ProxyConfig()
        self.ssh_manager = SSHManager()
        self.proxy_server = ProxyServer(self.proxy_config)

    def main_menu(self):
        options = [
            "Configurar Portas",
            "Gerenciar Usuários SSH",
            "Configurar Protocolos",
            "Gerenciar Backend",
            "Iniciar Proxy",
            "Sair"
        ]
        
        while True:
            terminal_menu = TerminalMenu(options)
            menu_entry_index = terminal_menu.show()
            
            if menu_entry_index == 0:
                self.configure_ports()
            elif menu_entry_index == 1:
                self.manage_ssh_users()
            elif menu_entry_index == 2:
                self.configure_protocols()
            elif menu_entry_index == 3:
                self.manage_backend()
            elif menu_entry_index == 4:
                self.start_proxy()
            elif menu_entry_index == 5:
                sys.exit(0)

    def configure_ports(self):
        port = input("Digite a porta para o proxy: ")
        protocol = input("Digite o protocolo (ws/wss/ssh/http/https): ")
        self.proxy_config.config['ports'][protocol] = int(port)
        self.proxy_config.save_config()

    def manage_ssh_users(self):
        username = input("Username: ")
        password = input("Password: ")
        expire_days = input("Dias até expirar (opcional): ")
        bandwidth = input("Limite de banda em KB/s (opcional): ")

        expire_date = None
        if expire_days:
            expire_date = (datetime.now() + timedelta(days=int(expire_days))).strftime('%Y-%m-%d')

        self.ssh_manager.add_user(username, password, expire_date, bandwidth)

    def configure_protocols(self):
        print("Protocolos disponíveis:", self.proxy_config.config['protocols'])
        protocol = input("Adicionar novo protocolo: ")
        if protocol:
            self.proxy_config.config['protocols'].append(protocol)
            self.proxy_config.save_config()

    def manage_backend(self):
        protocol = input("Protocolo: ")
        backend_url = input("URL do backend: ")
        self.proxy_config.config['backend_rules'][protocol] = backend_url
        self.proxy_config.save_config()

    def start_proxy(self):
        for protocol, port in self.proxy_config.config['ports'].items():
            threading.Thread(target=self.run_proxy, args=(port,)).start()
        print("Proxy iniciado em todas as portas configuradas")

    def run_proxy(self, port):
        asyncio.run(self.proxy_server.start_proxy(port))

if __name__ == "__main__":
    if os.geteuid() != 0:
        print("Este script precisa ser executado como root")
        sys.exit(1)

    menu = MenuInterface()
    menu.main_menu()