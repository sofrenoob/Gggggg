#!/usr/bin/env python3
import socket, threading, ssl, os, time
from datetime import datetime
from websocket_server import WebsocketServer

DEST = "/opt/alfaproxy"
with open(f"{DEST}/config.txt") as f:
    PORT = int(f.read().strip())

LOG = f"{DEST}/logs/alfaproxy.log"
PAYLOADS = open(f"{DEST}/payloads.txt").read()

def log(msg):
    with open(LOG, "a") as f:
        f.write(f"[{datetime.now()}] {msg}\n")

def handle_tcp(conn, addr):
    log(f"[TCP] Conexão de {addr}")
    try:
        conn.send(b"alfa-proxy\n")  # Autenticação simples
        data = conn.recv(1024)
        if not data:
            log(f"[TCP] {addr} desconectou sem autenticar.")
            conn.close()
            return
        log(f"[TCP] Autenticado de {addr}: {data.decode(errors='ignore')}")
        conn.send(PAYLOADS.encode())
    except Exception as e:
        log(f"[TCP] Erro: {e}")
    finally:
        conn.close()

def on_message(client, server, message):
    log(f"[WS] De {client['address']}: {message}")
    server.send_message(client, PAYLOADS)

def on_new_client(client, server):
    log(f"[WS] Novo cliente: {client['address']}")
    server.send_message(client, "alfa-proxy")
    time.sleep(0.5)
    server.send_message(client, PAYLOADS)

def start_websocket_server():
    ws_server = WebsocketServer(host="0.0.0.0", port=PORT+1, loglevel=0)
    ws_server.set_fn_new_client(on_new_client)
    ws_server.set_fn_message_received(on_message)
    log(f"[WS] WebSocket Server ativo na porta {PORT+1}")
    ws_server.run_forever()

def start_ssl_server():
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(f"{DEST}/cert.pem", f"{DEST}/key.pem")
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.bind(("", PORT))
    server.listen(100)
    log(f"[SSL] Proxy SSL ativo na porta {PORT}")

    with context.wrap_socket(server, server_side=True) as ssock:
        while True:
            try:
                conn, addr = ssock.accept()
                threading.Thread(target=handle_tcp, args=(conn, addr), daemon=True).start()
            except Exception as e:
                log(f"[SSL] Erro no accept: {e}")

def start_http_proxy():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.bind(("", PORT+2))
    server.listen(100)
    log(f"[HTTP] Proxy Tunnel ativo na porta {PORT+2}")

    while True:
        try:
            conn, addr = server.accept()
            log(f"[HTTP] Conexão de {addr}")
            threading.Thread(target=handle_tcp, args=(conn, addr), daemon=True).start()
        except Exception as e:
            log(f"[HTTP] Erro no accept: {e}")

def reconnect(service_func, delay=5):
    while True:
        try:
            service_func()
        except Exception as e:
            log(f"[RECONNECT] {service_func.__name__} caiu: {e}, reiniciando em {delay}s")
            time.sleep(delay)

if __name__ == "__main__":
    threading.Thread(target=reconnect, args=(start_ssl_server,), daemon=True).start()
    threading.Thread(target=reconnect, args=(start_websocket_server,), daemon=True).start()
    threading.Thread(target=reconnect, args=(start_http_proxy,), daemon=True).start()
    log("Todos os serviços ativos e monitorados!")

    while True:
        time.sleep(60)
