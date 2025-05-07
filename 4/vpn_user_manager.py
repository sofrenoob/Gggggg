import json
import os
from datetime import datetime

USER_DATA_FILE = "vpn_users.json"
BACKUP_FILE = "vpn_users_backup.json"

# Load initial user data
def load_users():
    if os.path.exists(USER_DATA_FILE):
        with open(USER_DATA_FILE, 'r') as file:
            return json.load(file)
    return {}

# Save user data to file
def save_users(users):
    with open(USER_DATA_FILE, 'w') as file:
        json.dump(users, file, indent=4)

# Backup user data
def backup_users(users):
    with open(BACKUP_FILE, 'w') as file:
        json.dump(users, file, indent=4)
    print("Backup realizado com sucesso.")

# Restore users from backup
def restore_from_backup(users):
    if not os.path.exists(BACKUP_FILE):
        print("Arquivo de backup não encontrado.")
        return
    with open(BACKUP_FILE, 'r') as file:
        backup_users = json.load(file)
    # Merge users from backup with existing users
    for username, details in backup_users.items():
        if username not in users:
            users[username] = details
            print(f"Usuário {username} restaurado do backup.")
        else:
            print(f"Usuário {username} já existe, não será substituído.")
    print("Restauração concluída.")

# Add new user
def add_user(users):
    username = input("Nome de usuário: ")
    if username in users:
        print("Usuário já existe.")
        return
    password = input("Senha: ")
    access_limit = int(input("Limite de acesso: "))
    expiration_date = input("Data de expiração (YYYY-MM-DD): ")
    users[username] = {
        "password": password,
        "access_limit": access_limit,
        "expiration_date": expiration_date,
        "online": False
    }
    print(f"Usuário {username} criado com sucesso.")

# Modify user details
def modify_user(users):
    username = input("Nome de usuário para modificar: ")
    if username not in users:
        print("Usuário não encontrado.")
        return
    print("O que deseja modificar?")
    print("1. Senha")
    print("2. Limite de acesso")
    print("3. Data de expiração")
    choice = input("Escolha: ")
    if choice == "1":
        new_password = input("Nova senha: ")
        users[username]["password"] = new_password
    elif choice == "2":
        new_limit = int(input("Novo limite de acesso: "))
        users[username]["access_limit"] = new_limit
    elif choice == "3":
        new_date = input("Nova data de expiração (YYYY-MM-DD): ")
        users[username]["expiration_date"] = new_date
    else:
        print("Escolha inválida.")
    print(f"Usuário {username} atualizado com sucesso.")

# List expired users
def list_expired_users(users):
    print("Usuários expirados:")
    for username, details in users.items():
        if datetime.strptime(details["expiration_date"], "%Y-%m-%d") < datetime.now():
            print(f"- {username}")

# Remove expired users
def remove_expired_users(users):
    expired_users = [username for username, details in users.items()
                     if datetime.strptime(details["expiration_date"], "%Y-%m-%d") < datetime.now()]
    for username in expired_users:
        del users[username]
    print("Usuários expirados removidos com sucesso.")

# Remove user
def remove_user(users):
    username = input("Nome de usuário para remover: ")
    if username in users:
        del users[username]
        print(f"Usuário {username} removido com sucesso.")
    else:
        print("Usuário não encontrado.")

# List online users
def list_online_users(users):
    print("Usuários online:")
    for username, details in users.items():
        if details["online"]:
            print(f"- {username}")

# Main menu
def main():
    users = load_users()
    while True:
        print("\n--- Menu ---")
        print("1. Criar usuário")
        print("2. Alterar usuário")
        print("3. Ver usuários expirados")
        print("4. Remover usuários expirados")
        print("5. Remover usuário")
        print("6. Ver usuários online")
        print("7. Backup de usuários")
        print("8. Restaurar usuários do backup")
        print("9. Sair")
        choice = input("Escolha: ")
        if choice == "1":
            add_user(users)
        elif choice == "2":
            modify_user(users)
        elif choice == "3":
            list_expired_users(users)
        elif choice == "4":
            remove_expired_users(users)
        elif choice == "5":
            remove_user(users)
        elif choice == "6":
            list_online_users(users)
        elif choice == "7":
            backup_users(users)
        elif choice == "8":
            restore_from_backup(users)
        elif choice == "9":
            save_users(users)
            print("Saindo...")
            break
        else:
            print("Escolha inválida.")

if __name__ == "__main__":
    main()