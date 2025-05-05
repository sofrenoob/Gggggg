#!/usr/bin/env python3
import asyncio
import aiohttp
from aiohttp import web
import threading
import json
import time
import os

# Lê configurações do JSON
def load_config():
    with open("/opt/ggproxy/config.json") as f:
        return json.load(f)

config = load_config()
TARGET_BACKEND = config["backend_target"]
LOG_FILE = config["log_file"]

# Função para logar requisições
def log_request(port, method, path, status):
    with open(LOG_FILE, 'a') as f:
        log_line = f"{time.ctime()} | Porta {port} | {method} {path} -> {status}\n"
        f.write(log_line)

# Função que faz proxy da request para o backend
async def handle_proxy(request):
    target_url = TARGET_BACKEND + str(request.rel_url)
    method = request.method
    headers = dict(request.headers)

    try:
        async with aiohttp.ClientSession() as session:
            async with session.request(method, target_url, headers=headers, data=await request.read()) as resp:
                body = await resp.read()
                status = resp.status
                log_request(request.app["port"], method, request.rel_url, status)
                return web.Response(status=status, headers=resp.headers, body=body)

    except Exception as e:
        log_request(request.app["port"], method, request.rel_url, "500")
        return web.Response(status=500, text=f"Proxy Error: {str(e)}")

# Inicia servidor proxy em uma porta
def start_proxy_on_port(port):
    app = web.Application()
    app.router.add_route('*', '/{path_info:.*}', handle_proxy)
    app["port"] = port
    print(f"Proxy HTTP ativo na porta {port} 🥷")
    web.run_app(app, port=port)

# Inicia todas as portas em threads
def start_multiport_proxy():
    threads = []
    for port in config["ports"]:
        t = threading.Thread(target=start_proxy_on_port, args=(port,))
        t.daemon = True
        t.start()
        threads.append(t)

    for t in threads:
        t.join()

if __name__ == "__main__":
    start_multiport_proxy()
