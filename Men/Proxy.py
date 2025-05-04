#!/usr/bin/env python3
# encoding: utf-8
import asyncio
import socket
from asyncio import StreamReader, StreamWriter
import signal
import sys
from http import HTTPStatus

# Configurações do servidor
IP = '0.0.0.0'
PORT = 80
PASS = ''
BUFLEN = 8196 * 8
TIMEOUT = 60
DEFAULT_HOST = '0.0.0.0:22'
RESPONSE = f"HTTP/1.1 200 OK\r\n\r\n"

# ==========================
# Funções utilitárias
# ==========================
async def handle_client(reader: StreamReader, writer: StreamWriter):
    """Manipula conexões do cliente."""
    try:
        client_address = writer.get_extra_info('peername')
        print(f"Conexão recebida de {client_address}")

        # Recebe o cabeçalho inicial
        data = await reader.read(BUFLEN)
        if not data:
            return

        host_port = find_header(data.decode('utf-8'), 'X-Real-Host') or DEFAULT_HOST
        passwd = find_header(data.decode('utf-8'), 'X-Pass')

        # Verifica senha
        if PASS and passwd != PASS:
            writer.write(b"HTTP/1.1 400 WrongPass!\r\n\r\n")
            await writer.drain()
            return

        # Conecta ao destino
        remote_reader, remote_writer = await asyncio.open_connection(*host_port.split(':'))
        writer.write(RESPONSE.encode('utf-8'))
        await writer.drain()

        # Encaminha tráfego entre cliente e destino
        await asyncio.gather(
            pipe_stream(reader, remote_writer),
            pipe_stream(remote_reader, writer)
        )

    except Exception as e:
        print(f"Erro: {e}")
    finally:
        writer.close()
        await writer.wait_closed()

async def pipe_stream(reader: StreamReader, writer: StreamWriter):
    """Encaminha dados entre streams."""
    try:
        while not reader.at_eof():
            data = await reader.read(BUFLEN)
            if data:
                writer.write(data)
                await writer.drain()
    except Exception as e:
        print(f"Erro durante o encaminhamento: {e}")
    finally:
        writer.close()
        await writer.wait_closed()

def find_header(headers: str, header_name: str) -> str:
    """Encontra o valor de um cabeçalho HTTP."""
    for line in headers.split('\r\n'):
        if line.lower().startswith(header_name.lower() + ':'):
            return line.split(':', 1)[1].strip()
    return ''

# ==========================
# Servidor WebSocket
# ==========================
async def websocket_handler(reader: StreamReader, writer: StreamWriter):
    """Manipula conexões WebSocket."""
    try:
        print("Conexão WebSocket estabelecida")
        # Implementar lógica de WebSocket aqui
        await handle_client(reader, writer)
    except Exception as e:
        print(f"Erro WebSocket: {e}")

# ==========================
# Inicialização do Servidor
# ==========================
async def start_server():
    """Inicia o servidor."""
    server = await asyncio.start_server(handle_client, IP, PORT)
    print(f"Servidor escutando em {IP}:{PORT}")

    async with server:
        await server.serve_forever()

def main():
    """Ponto de entrada principal."""
    try:
        asyncio.run(start_server())
    except KeyboardInterrupt:
        print("\nServidor interrompido manualmente.")
    except Exception as e:
        print(f"Erro no servidor: {e}")

if __name__ == '__main__':
    main()