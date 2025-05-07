import os
import platform
import psutil
import datetime
from rich.console import Console
from rich.panel import Panel
from rich.table import Table


# Funções para as opções do painel
def criar_usuario():
    print("Opção [01]: Criar Usuário selecionada.")
    print("Função para criar usuário ainda não implementada.")


def criar_teste():
    print("Opção [02]: Criar Teste selecionada.")
    print("Função para criar teste ainda não implementada.")


def remover_usuario():
    print("Opção [03]: Remover Usuário selecionada.")
    print("Função para remover usuário ainda não implementada.")


def renovar_usuario():
    print("Opção [04]: Renovar Usuário selecionada.")
    print("Função para renovar usuário ainda não implementada.")


def usuarios_online():
    print("Opção [05]: Usuários Online selecionada.")
    print("Mostrando usuários online (a ser implementado).")


# Dicionário de opções
opcoes = {
    "01": criar_usuario,
    "02": criar_teste,
    "03": remover_usuario,
    "04": renovar_usuario,
    "05": usuarios_online,
    # Adicione mais opções conforme necessário
}


# Função para obter informações do sistema
def get_system_info():
    uname = platform.uname()
    ram = psutil.virtual_memory()
    cpu_percent = psutil.cpu_percent(interval=1)
    users = [u.name for u in psutil.users()]
    return {
        "os": f"{uname.system} {uname.release}",
        "time": datetime.datetime.now().strftime("%H:%M:%S"),
        "ram_total": f"{ram.total // (1024 ** 2)} MB",
        "ram_used": f"{ram.percent}%",
        "cpu_cores": os.cpu_count(),
        "cpu_used": f"{cpu_percent}%",
        "users_online": len(set(users)),
        "users_expired": 0,  # Pode ser atualizado com lógica real
        "users_total": len(users),
    }


# Função principal para criar o painel
def create_terminal_panel(console):
    # Obter informações do sistema
    system_info = get_system_info()

    # Banner no topo
    banner = Panel(
        "[bold white on red] ← ALFALEMOS MANAGER PRO → [/bold white on red]",
        border_style="bright_blue",
        padding=(1, 2),
    )

    # Informações do sistema
    system_table = Table.grid(expand=True)
    system_table.add_column(justify="left", style="bold cyan")
    system_table.add_column(justify="right", style="bold white")
    system_table.add_row("SISTEMA", f"OS: {system_info['os']}")
    system_table.add_row("HORA", f"{system_info['time']}")
    system_table.add_row("", "")
    system_table.add_row(
        "MEMORIA RAM", f"Total: {system_info['ram_total']} | Em Uso: {system_info['ram_used']}"
    )
    system_table.add_row(
        "PROCESSADOR", f"Nucleos: {system_info['cpu_cores']} | Em Uso: {system_info['cpu_used']}"
    )
    system_table.add_row("", "")
    system_table.add_row(
        "Onlines",
        f"{system_info['users_online']}  | Expirados: {system_info['users_expired']} | Total: {system_info['users_total']}",
    )

    # Menu de opções
    options_table = Table(title="Opções", title_style="bold cyan", border_style="bright_blue")
    for i in range(1, 24):  # Gerar até 23 opções
        options_table.add_row(f"[{i:02}] Opção {i}")

    # Painel final
    console.print(banner)
    console.print(Panel(system_table, border_style="bright_blue"))
    console.print(options_table)
    console.print("[bold cyan]INFORME UMA OPÇÃO:[/bold cyan] ", end="")


# Execução
if __name__ == "__main__":
    console = Console()
    while True:
        create_terminal_panel(console)
        opcao = input("> ").strip()
        if opcao in opcoes:
            opcoes[opcao]()
        elif opcao == "00":
            print("Saindo do menu...")
            break
        else:
            print("Opção inválida! Tente novamente.")