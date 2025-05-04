#!/usr/bin/env python3
# encoding: utf-8
import os
import subprocess

# Configurações iniciais
CONFIG = {
    "ip": "0.0.0.0",
    "port": 80,
    "status": "desativado"
}

def ativar_proxy():
    """Ativa o proxy com as configurações atuais"""
    global CONFIG
    print("\nAtivando Proxy...")
    try:
        # Substitua este comando pelo comando real para iniciar o proxy
        subprocess.Popen(["python3", "proxy.py"])
        CONFIG["status"] = "ativo"
        print(f"Proxy ativado em {CONFIG['ip']}:{CONFIG['port']}")
    except Exception as e:
        print(f"Erro ao ativar o proxy: {e}")

def abrir_porta():
    """Configura uma nova porta"""
    global CONFIG
    nova_porta = input("Digite a nova porta: ")
    if nova_porta.isdigit() and 1 <= int(nova_porta) <= 65535:
        CONFIG["port"] = int(nova_porta)
        print(f"Porta configurada para {CONFIG['port']}")
    else:
        print("Porta inválida! Escolha um número entre 1 e 65535.")

def configurar_ip():
    """Configura um novo IP"""
    global CONFIG
    novo_ip = input("Digite o novo IP (padrão é 0.0.0.0 para todas as interfaces): ")
    CONFIG["ip"] = novo_ip
    print(f"IP configurado para {CONFIG['ip']}")

def verificar_status():
    """Verifica o status atual do proxy"""
    global CONFIG
    print("\n=== Status do Proxy ===")
    print(f"IP: {CONFIG['ip']}")
    print(f"Porta: {CONFIG['port']}")
    print(f"Status: {CONFIG['status']}")
    print("========================")

def exibir_menu():
    """Exibe o menu principal"""
    while True:
        print("\n=== Menu do Proxy ===")
        print("1. Ativar Proxy")
        print("2. Configurar Porta")
        print("3. Configurar IP")
        print("4. Verificar Status")
        print("5. Sair")
        opcao = input("Escolha uma opção: ")

        if opcao == "1":
            ativar_proxy()
        elif opcao == "2":
            abrir_porta()
        elif opcao == "3":
            configurar_ip()
        elif opcao == "4":
            verificar_status()
        elif opcao == "5":
            print("Saindo...")
            break
        else:
            print("Opção inválida! Tente novamente.")

if __name__ == "__main__":
    exibir_menu()