#!/usr/bin/env python3
import asyncio
import websockets
import aiohttp
from aiohttp import web, ClientSession
import threading
import json
import time

# Config
HTTP_PORT = 8080
WS_PORT = 8081
API_PORT = 8082
TARGET_BACKEND = 'http://127.0.0.1:5000'
logfile = 'proxy_logs.txt'

# Plugin exemplo (pode adicionar mais via lista)
def example_plugin(data):
    print("[PLUGIN] Interceptado:", data)

plugins = [example_plugin]

# Log função
def log(data):
    with open(logfile, 'a') as f:
        f.write(f"{time.ctime()} | {data}\n")

# HTTP Proxy Handler
async def handle_http(request):
    log(f"HTTP {request.method} {request.rel_url}")
    for plugin in plugins:
        plugin(f"HTTP Request {request.rel_url}")
    
    target_url = str(TARGET_BACKEND) + str(request.rel_url)
    async with ClientSession() as session:
        async with session.request(request.method, target_url, headers=request.headers, data=await request.read()) as resp:
            body = await resp.read()
            return web.Response(status=resp.status, headers=resp.headers, body=body)

# WebSocket Proxy Handler
async def ws_handler(websocket, path):
    log(f"Nova conexão WS: {path}")
    async with websockets.connect(f"ws://127.0.0.1:5001{path}") as ws_backend:
        async def client_to_server():
            async for message in websocket:
                log(f"WS Cliente -> Backend: {message}")
                await ws_backend.send(message)
                for plugin in plugins:
                    plugin(f"WS In: {message}")

        async def server_to_client():
            async for message in ws_backend:
                log(f"WS Backend -> Cliente: {message}")
                await websocket.send(message)

        await asyncio.gather(client_to_server(), server_to_client())

# API Proxy Handler (JWT-aware)
async def handle_api(request):
    token = request.headers.get("Authorization")
    log(f"API {request.method} {request.rel_url} | Token: {token}")
    for plugin in plugins:
        plugin(f"API Call {request.rel_url} | Token: {token}")

    target_url = str(TARGET_BACKEND) + str(request.rel_url)
    async with ClientSession() as session:
        async with session.request(request.method, target_url, headers=request.headers, data=await request.read()) as resp:
            body = await resp.read()
            return web.Response(status=resp.status, headers=resp.headers, body=body)

# Iniciar HTTP Proxy
def start_http_proxy():
    app = web.Application()
    app.router.add_route('*', '/{path_info:.*}', handle_http)
    web.run_app(app, port=HTTP_PORT)

# Iniciar WS Proxy
def start_ws_proxy():
    start_server = websockets.serve(ws_handler, "0.0.0.0", WS_PORT)
    asyncio.get_event_loop().run_until_complete(start_server)
    asyncio.get_event_loop().run_forever()

# Iniciar API Proxy
def start_api_proxy():
    app = web.Application()
    app.router.add_route('*', '/{path_info:.*}', handle_api)
    web.run_app(app, port=API_PORT)

# Mostrar Logs
def show_logs():
    with open(logfile) as f:
        print(f.read())

# Menu Interativo
def menu():
    while True:
        print("""
===== Proxy VPN HackTool 🥷 =====
1. Iniciar HTTP Proxy
2. Iniciar WebSocket Proxy
3. Iniciar API Proxy
4. Ver logs
5. Sair
""")
        choice = input("Escolha: ")
        if choice == '1':
            threading.Thread(target=start_http_proxy, daemon=True).start()
            print("[+] HTTP Proxy ativo na porta", HTTP_PORT)
        elif choice == '2':
            threading.Thread(target=start_ws_proxy, daemon=True).start()
            print("[+] WebSocket Proxy ativo na porta", WS_PORT)
        elif choice == '3':
            threading.Thread(target=start_api_proxy, daemon=True).start()
            print("[+] API Proxy ativo na porta", API_PORT)
        elif choice == '4':
            show_logs()
        elif choice == '5':
            print("Encerrando...")
            exit(0)
        else:
            print("Opção inválida.")

# Inicia menu
if __name__ == "__main__":
    menu()





#!/bin/bash

# Verifica permissão root
if [[ "$EUID" -ne 0 ]]; then
  echo "Por favor execute como root."
  exit
fi

echo ">>> Instalando GGProxy HackTool Master 🥷"

# Cria diretório de instalação
mkdir -p /opt/ggproxy

# Faz download do script principal
echo "Baixando proxy_master_hacktool.py..."
curl -o /opt/ggproxy/proxy_master_hacktool.py https://raw.githubusercontent.com/sofrenoob/Gggggg/main/mm/mm/proxy_master_hacktool.py

# Dá permissão de execução
chmod +x /opt/ggproxy/proxy_master_hacktool.py

# Instala dependências Python se necessário
echo "Instalando dependências Python..."
pip3 install --upgrade aiohttp websockets

# Cria service systemd
echo "Criando serviço systemd para inicialização automática..."

cat <<EOL > /etc/systemd/system/ggproxyhack.service
[Unit]
Description=GGProxy HackTool Master Service
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/ggproxy/proxy_master_hacktool.py
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOL

# Ativa e inicia o serviço
systemctl daemon-reload
systemctl enable ggproxyhack.service
systemctl start ggproxyhack.service

echo "Instalação concluída."
echo "Proxy HackTool ativo! Para ver status: systemctl status ggproxyhack"
