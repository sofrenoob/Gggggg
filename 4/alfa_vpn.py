#!/usr/bin/env python3
import os, platform, psutil, subprocess, datetime, time, socket, re, yaml, shutil, sys, textwrap
from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich import box
import questionary

# ---------------------------------------------------
# utilidades
# ---------------------------------------------------
console = Console()

def sh(cmd, capture=True):
    """executa shell; devolve saída ou rc"""
    if capture:
        return subprocess.getoutput(cmd)
    return subprocess.call(cmd, shell=True)

def is_root():
    return os.geteuid() == 0

def load_services():
    with open(os.path.join(os.path.dirname(__file__), "services.yml")) as f:
        return yaml.safe_load(f)

SERVICES = load_services()

# ---------------------------------------------------
# info do sistema (painel superior)
# ---------------------------------------------------
def get_sys_info():
    mem = psutil.virtual_memory()
    cpu = psutil.cpu_percent(interval=0.5)
    now = datetime.datetime.now().strftime("%d/%m/%Y %H:%M:%S")
    os_name = f"{platform.system()} {platform.release()}"
    online_users = len(sh("who", True).splitlines())
    ports = parse_ports()
    return dict(mem=mem, cpu=cpu, now=now, os=os_name,
                users=online_users, ports=ports)

def parse_ports():
    lines = sh("ss -tuln").splitlines()[1:]
    ports = {}
    for l in lines:
        parts = l.split()
        proto = parts[0]
        local = parts[4]
        port = local.split(':')[-1]
        ports.setdefault(port, set()).add(proto)
    # tenta descobrir serviço via /etc/services
    service_map = {}
    for p in ports.keys():
        try:
            srv = socket.getservbyport(int(p))
        except:                 # unknown
            srv = "?"
        service_map[p] = srv
    return service_map

def header():
    info = get_sys_info()
    table = Table.grid(expand=True)
    table.add_column(justify="left")
    table.add_column(justify="right")
    table.add_row(f"[cyan]{info['os']}[/cyan]",
                  f"[yellow]{info['now']}[/yellow]")
    table.add_row(f"CPU: [red]{info['cpu']} %[/red]",
                  f"RAM: [green]{info['mem'].percent} %[/green]")
    port_str = ", ".join([f"{srv}:{port}" for port, srv in info['ports'].items()])
    table.add_row(f"Portas abertas: {port_str}", f"Usuários on-line: {info['users']}")
    return Panel.fit(table, title="[bold magenta]Alfa VPN[/bold magenta]", box=box.ROUNDED)

# ---------------------------------------------------
# serviços
# ---------------------------------------------------
def service_menu():
    while True:
        console.clear()
        console.print(header())
        choice = questionary.select(
            "Gerenciar conexões",
            choices=[
                "Ativar serviço", "Desativar serviço",
                "Instalar serviço", "Desinstalar serviço",
                "Status do serviço", "Abrir porta", "Fechar porta",
                "Voltar"
            ]).ask()
        if choice == "Voltar" or choice is None:
            break
        if choice.startswith("Ativar"):
            start_stop_service(True)
        elif choice.startswith("Desativar"):
            start_stop_service(False)
        elif choice.startswith("Instalar"):
            install_remove_service(True)
        elif choice.startswith("Desinstalar"):
            install_remove_service(False)
        elif choice.startswith("Status"):
            status_service()
        elif choice.startswith("Abrir"):
            open_close_port(True)
        elif choice.startswith("Fechar"):
            open_close_port(False)

def svc_picker(prompt):
    return questionary.select(prompt, choices=list(SERVICES.keys()) + ["Cancelar"]).ask()

def start_stop_service(start=True):
    name = svc_picker("Qual serviço?")
    if name == "Cancelar":
        return
    svc = SERVICES[name]
    port = questionary.text(f"Porta para usar [{svc['default_port']}]:").ask() or str(svc['default_port'])
    if start:
        sh(f"systemctl start {svc['systemd']}")
        if port != str(svc['default_port']):
            sh(f"sed -i 's/{svc['default_port']}/{port}/g' {svc['conf']}")
            sh(f"systemctl restart {svc['systemd']}")
        console.print(f"[green]✔ {name} iniciado na porta {port}[/green]")
    else:
        sh(f"systemctl stop {svc['systemd']}")
        console.print(f"[red]✖ {name} parado[/red]")
    input("Enter para continuar...")

def install_remove_service(install=True):
    name = svc_picker("Qual serviço?")
    if name == "Cancelar": return
    pkg = SERVICES[name]['package']
    cmd = f"{'apt -y install' if install else 'apt -y purge'} {pkg}"
    if shutil.which("yum"):  # rpm
        cmd = f"yum -y {'install' if install else 'remove'} {pkg}"
    console.print(f"Executando: {cmd}")
    sh(cmd, capture=False)
    input("Enter para continuar...")

def status_service():
    name = svc_picker("Qual serviço?")
    if name == "Cancelar": return
    os.system(f"systemctl status {SERVICES[name]['systemd']}")
    input("Enter para continuar...")

def open_close_port(open_=True):
    port = questionary.text("Número da porta:").ask()
    action = "allow" if open_ else "delete allow"
    if shutil.which("ufw"):
        sh(f"ufw {action} {port}")
    elif shutil.which("firewall-cmd"):
        zone = "--permanent --add-port" if open_ else "--permanent --remove-port"
        sh(f"firewall-cmd {zone}={port}/tcp")
        sh("firewall-cmd --reload")
    console.print("[green]OK[/green]")
    input("Enter para continuar...")

# ---------------------------------------------------
# usuários (PPTP e Squid)
# ---------------------------------------------------
def users_menu():
    while True:
        console.clear()
        console.print(header())
        choice = questionary.select(
            "Gerenciar usuários",
            choices=[
                "Criar usuário", "Alterar usuário", "Excluir usuário",
                "Listar usuários", "Voltar"]).ask()
        if choice == "Voltar" or choice is None:
            break
        if choice.startswith("Criar"):
            create_user()
        elif choice.startswith("Alterar"):
            modify_user()
        elif choice.startswith("Excluir"):
            delete_user()
        elif choice.startswith("Listar"):
            list_user()

def create_user():
    username = questionary.text("Usuário:").ask()
    password = questionary.password("Senha:").ask()
    limite = questionary.text("Limite (0=ilimitado):").ask()
    data = questionary.text("Expira em (AAAA-MM-DD ou 0):").ask()
    with open("/etc/ppp/chap-secrets", "a") as f:
        f.write(f'{username} * {password} *\n')
    sh(f"htpasswd -b /etc/squid/passwd {username} {password}")
    console.print("[green]Usuário criado[/green]")
    input("Enter...")

def modify_user():
    username = questionary.text("Usuário a alterar:").ask()
    new_pass = questionary.password("Nova senha:").ask()
    sh(f"htpasswd -b /etc/squid/passwd {username} {new_pass}")
    sh(f"sed -i 's|^{username}[[:space:]].*|{username} * {new_pass} *|' /etc/ppp/chap-secrets")
    console.print("[green]Alterado[/green]")
    input("Enter...")

def delete_user():
    username = questionary.text("Usuário a excluir:").ask()
    sh(f"sed -i '/^{username} /d' /etc/ppp/chap-secrets")
    sh(f"htpasswd -D /etc/squid/passwd {username}")
    console.print("[red]Usuário removido[/red]")
    input("Enter...")

def list_user():
    console.print(sh("cut -d: -f1 /etc/passwd | head"))
    console.print(sh("cut -d' ' -f1 /etc/ppp/chap-secrets"))
    input("Enter...")

# ---------------------------------------------------
# monitoramento (Glances)
# ---------------------------------------------------
def monitor_menu():
    os.system("glances")

# ---------------------------------------------------
# menu principal
# ---------------------------------------------------
def main_menu():
    if not is_root():
        console.print("[red]Execute como root[/red]")
        sys.exit(1)
    while True:
        console.clear()
        console.print(header())
        choice = questionary.select(
            "Menu principal",
            choices=[
                "Gerenciar conexões",
                "Gerenciar usuários",
                "Monitorar sistema (Glances)",
                "Sair"]).ask()
        if choice is None or choice == "Sair":
            break
        if choice.startswith("Gerenciar conexões"):
            service_menu()
        elif choice.startswith("Gerenciar usuários"):
            users_menu()
        elif choice.startswith("Monitorar"):
            monitor_menu()

if __name__ == "__main__":
    try:
        main_menu()
    except KeyboardInterrupt:
        print()
