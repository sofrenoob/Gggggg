import os
import platform
import psutil
import datetime
from time import sleep
from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.live import Live

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

# Função para criar a tabela de status do sistema
def create_status_table():
    # Processos que mais consomem CPU e RAM
    processes = sorted(psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_percent']),
                       key=lambda p: p.info['cpu_percent'], reverse=True)[:5]

    # Portas abertas
    connections = psutil.net_connections(kind='inet')
    open_ports = [conn.laddr.port for conn in connections if conn.status == 'LISTEN']

    # Criação da tabela
    table = Table(title="Super Visor do Sistema", title_style="bold red")
    table.add_column("Categoria", style="bold cyan", no_wrap=True)
    table.add_column("Detalhes", style="bold white")

    # Status de portas abertas
    table.add_row("Portas Abertas", ", ".join(map(str, open_ports)) or "Nenhuma")

    # Processos ativos (top 5)
    table.add_row("Top Processos (CPU)",
                  "\n".join(f"{proc.info['name']} ({proc.info['cpu_percent']}%)"
                            for proc in processes if proc.info['cpu_percent'] > 0))

    # Processos ativos (top 5 RAM)
    table.add_row("Top Processos (RAM)",
                  "\n".join(f"{proc.info['name']} ({proc.info['memory_percent']:.1f}%)"
                            for proc in processes if proc.info['memory_percent'] > 0))

    return table

# Função principal para criar o painel
def create_terminal_panel():
    console = Console()
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

    # Exibição dinâmica no terminal
    with Live(console=console, refresh_per_second=1) as live:
        while True:
            # Atualizar os painéis
            layout = Panel.fit(
                f"{banner}\n\n{Panel(system_table, border_style='bright_blue')}\n\n"
                f"{Panel(options_table, border_style='bright_blue')}\n\n"
                f"{create_status_table()}",
                title="Painel Principal",
                border_style="green",
            )
            live.update(layout)
            sleep(1)

if __name__ == "__main__":
    create_terminal_panel()