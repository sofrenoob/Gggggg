#!/usr/bin/env python3

# AlfaMenager API REST
# by @alfalemos 👾🥷

from flask import Flask, jsonify, request
import subprocess
import json
import os

app = Flask(__name__)

MEMORY_FILE = "memory.json"
LOG_FILE = "logs/conexoes.log"

# Endpoint: Status dos túneis (screen)
@app.route('/tuneis', methods=['GET'])
def tuneis_status():
    result = subprocess.getoutput("screen -ls")
    return jsonify({"status": "ok", "tuneis": result})

# Endpoint: Últimos logs
@app.route('/logs', methods=['GET'])
def ver_logs():
    if os.path.exists(LOG_FILE):
        with open(LOG_FILE) as f:
            logs = f.readlines()[-200:]
        return jsonify({"logs": logs})
    else:
        return jsonify({"erro": "Arquivo de log não encontrado!"}), 404

# Endpoint: Memória de conexões
@app.route('/memoria', methods=['GET'])
def memoria():
    if os.path.exists(MEMORY_FILE):
        with open(MEMORY_FILE) as f:
            memoria = json.load(f)
        return jsonify({"memoria": memoria})
    else:
        return jsonify({"erro": "Arquivo de memória não encontrado!"}), 404

# Endpoint: Reiniciar proxy listener
@app.route('/reiniciar-proxy', methods=['POST'])
def reiniciar_proxy():
    subprocess.run("screen -ls | grep proxy_ | cut -d. -f1 | awk '{print $1}' | xargs kill", shell=True)
    subprocess.run("bash proxy_listener.sh", shell=True)
    return jsonify({"status": "reiniciado"})

# Endpoint: Ativar DNS avançado
@app.route('/ativar-dns', methods=['POST'])
def ativar_dns():
    subprocess.run("bash dns_custom.sh", shell=True)
    return jsonify({"status": "dns ativado"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
