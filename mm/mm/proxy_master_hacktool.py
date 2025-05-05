#!/usr/bin/env python3
import asyncio
import aiohttp
from aiohttp import web
import websockets
import threading
import json
import time
import os
import subprocess

# === CONFIG ===
CONFIG_FILE = "/opt/ggproxy/config.json"
with open(CONFIG_FILE) as f:
    config = json.load(f)

TARGET_BACKEND = config["backend_target"]
LOG_FILE = config["log_file"]

# === LOG ===
def log(data):
    with open(LOG_FILE, 'a') as f:
        f.write(f"{time.ctime()} | {data}\n")

# === HTTP PROXY ===
async def handle_http(request):
    target_url = TARGET_BACKEND + str(request.rel_url)
    method = request.method
    headers = dict(request.headers)

    try:
        async with aiohttp.ClientSession() as session:
            async with session.request(method, target_url, headers=headers, data=await request.read()) as resp:
                body = await resp.read()
                status = resp.status
                log(f"HTTP {method} {request.rel_url} -> {status}")
                return web.Response(status=status, headers=resp.headers, body=body)
    except Exception as e:
        log(f"HTTP {method} {request.rel_url} -> 500 {e}")
        return web.Response(status=500, text=f"Proxy Error: {str(e)}")

def start_http_proxy(port):
    app = web.Application()
    app.router.add_route('*', '/{path_info:.*}', handle_http)
    print(f"[+] HTTP Proxy ativo na porta {port}")
    web.run_app(app, port=port)

def start_multiport_proxy():
    threads = []
    for port in config["ports"]:
        t = threading.Thread(target=start_http_proxy, args=(port,))
        t.daemon = True
        t.start()
        threads.append(t)
    for t in threads:
        t.join()

# === WEBSOCKET PROXY ===
async def ws_handler(websocket, path):
    log(f"WS conexão: {path}")
    async with websockets.connect(f"ws://127.0.0.1:5001{path}") as ws_backend:
        async def client_to_server():
            async for message in websocket:
                log(f"WS Cliente -> Backend: {message}")
                await ws_backend.send(message)
        async def server_to_client():
            async for message in ws_backend:
                log(f"WS Backend -> Cliente: {message}")
                await websocket.send(message)
        await asyncio.gather(client_to_server(), server_to_client())

def start_ws_proxy():
    start_server = websockets.serve(ws_handler, "0.0.0.0", config["ws_port"])
    asyncio.get_event_loop().run_until_complete(start_server)
    print(f"[+] WebSocket Proxy ativo na porta {config['ws_port']}")
    asyncio.get_event_loop().run_forever()

# === LOG VIEWER ===
def show_logs():
    os.system(f"tail -f {LOG_FILE}")

# === STATUS DE PORTAS ===
def check_ports():
    print("\n=== PORTAS ATIVAS ===")
    subprocess.call("ss -tulpn | grep LISTEN", shell=True)

# === EDIT CONFIG ===
def edit_config():
    os.system(f"nano {CONFIG_FILE}")

# === MENU PRINCIPAL ===
def menu():
    while True:
        print(f"""
=== GGProxy HackTool 🥷 v2 ===
1. Iniciar Multiporta HTTP Proxy
2. Iniciar WebSocket Proxy
3. Ver Logs em Tempo Real
4. Verificar Portas Ativas
5. Editar config.json
6. Reiniciar Proxies
7. Sair
""")
        choice = input("Escolha: ")
        if choice == '1':
            threading.Thread(target=start_multiport_proxy, daemon=True).start()
            print("[+] Multiporta HTTP Proxy iniciado.")
        elif choice == '2':
            threading.Thread(target=start_ws_proxy, daemon=True).start()
            print("[+] WebSocket Proxy iniciado.")
        elif choice == '3':
            show_logs()
        elif choice == '4':
            check_ports()
        elif choice == '5':
            edit_config()
        elif choice == '6':
            os.system("systemctl restart ggproxyhack.service")
            print("[+] Proxies reiniciados.")
        elif choice == '7':
            print("Encerrando...")
            exit(0)
        else:
            print("Opção inválida.")

if __name__ == "__main__":
    menu()
