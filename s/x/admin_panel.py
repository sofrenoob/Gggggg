import os
import subprocess

def start_proxy():
    print("Iniciando o servidor proxy...")
    subprocess.run(["python3", "/opt/proxy.py/proxy.py", "--port", "8080"])

def stop_proxy():
    print("Parando o servidor proxy...")
    # Exemplo de comando para parar (pode precisar de ajustes)
    subprocess.run(["pkill", "-f", "proxy.py"])

def configure_proxy():
    print("Configuração do proxy (exemplo)...")
    # Adicione opções de configuração aqui
    print("Configuração concluída.")

def show_menu():
    while True:
        print("\n===== Painel Administrativo =====")
        print("1. Iniciar Proxy")
        print("2. Parar Proxy")
        print("3. Configurar Proxy")
        print("4. Sair")
        choice = input("Escolha uma opção: ")
        
        if choice == "1":
            start_proxy()
        elif choice == "2":
            stop_proxy()
        elif choice == "3":
            configure_proxy()
        elif choice == "4":
            print("Saindo...")
            break
        else:
            print("Opção inválida. Tente novamente.")

if __name__ == "__main__":
    show_menu()