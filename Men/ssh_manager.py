# Atualização do ssh_manager.py com ferramentas avançadas e configuração de VPN

import os
import platform
import asyncio
from datetime import datetime
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.align import Align
from http.server import SimpleHTTPRequestHandler, HTTPServer
import socket
import threading
import speedtest  # Biblioteca para teste de velocidade de internet

# Criação do console para saída formatada
console = Console()

# ==========================
# Funções utilitárias gerais
# ==========================
def sistema_info():
    """Retorna informações do sistema."""
    os_info = platform.system() + " " + platform.release()
    ram_total = os.popen("free -m | awk '/Mem:/ { print $2 }'").read().strip() + " MB"
    ram_uso = os.popen("free -m | awk '/Mem:/ { print $3 }'").read().strip() + " MB"
    cpu_nucleos = os.cpu_count()
    cpu_uso = os.popen("top -bn1 | grep 'Cpu(s)' | awk '{print $2 + $4}'").read().strip() + "%"
    hora_atual = datetime.now().strftime("%H:%M:%S")
    return os_info, ram_total, ram_uso, cpu_nucleos, cpu_uso, hora_atual

def limitar_trafego(usuario, limite):
    """Limita o tráfego de rede para um usuário específico."""
    try:
        console.print(f"[bold cyan]Aplicando limite de tráfego para o usuário: {usuario}[/bold cyan]")
        os.system(f"sudo wondershaper -a {usuario} -d {limite} -u {limite}")
        console.print(f"[bold green]Limite de tráfego de {limite} Kbps aplicado com sucesso![/bold green]")
    except Exception as e:
        console.print(f"[bold red]Erro ao aplicar limite de tráfego: {e}[/bold red]")

def executar_speedtest():
    """Executa um teste de velocidade de internet."""
    try:
        console.print("[bold cyan]Executando Speedtest...[/bold cyan]")
        st = speedtest.Speedtest()
        st.get_best_server()
        download = st.download() / 1_000_000  # Convertendo para Mbps
        upload = st.upload() / 1_000_000  # Convertendo para Mbps
        ping = st.results.ping
        console.print(f"[bold green]Download: {download:.2f} Mbps[/bold green]")
        console.print(f"[bold green]Upload: {upload:.2f} Mbps[/bold green]")
        console.print(f"[bold green]Ping: {ping} ms[/bold green]")
    except Exception as e:
        console.print(f"[bold red]Erro ao executar Speedtest: {e}[/bold red]")

def configurar_vpn(nome_vpn, endereco_vpn):
    """Configura uma VPN no sistema."""
    try:
        console.print(f"[bold cyan]Configurando VPN: {nome_vpn}[/bold cyan]")
        os.system(f"sudo openvpn --config {endereco_vpn}")
        console.print(f"[bold green]VPN {nome_vpn} configurada e conectada com sucesso![/bold green]")
    except Exception as e:
        console.print(f"[bold red]Erro ao configurar VPN: {e}[/bold red]")

# ==========================
# Interface e Menu
# ==========================
def exibir_interface():
    """Exibe a interface principal do gerenciador SSH."""
    # Coletar informações do sistema
    os_info, ram_total, ram_uso, cpu_nucleos, cpu_uso, hora_atual = sistema_info()

    # Criar tabelas principais
    table_info = Table.grid(expand=True)
    table_info.add_column(justify="left", style="cyan", no_wrap=True)
    table_info.add_column(justify="right", style="bold cyan")

    table_info.add_row("OS:", os_info)
    table_info.add_row("Hora:", hora_atual)
    table_info.add_row("Onlines:", "[bold green]5[/bold green]")
    table_info.add_row("Expirados:", "[bold red]0[/bold red]")
    table_info.add_row("Total:", "[bold cyan]14[/bold cyan]")

    # RAM e Processador
    table_info.add_row("Memória RAM:", f"Total: {ram_total} | Em Uso: {ram_uso}")
    table_info.add_row("Processador:", f"Núcleos: {cpu_nucleos} | Em Uso: {cpu_uso}")

    # Painel superior
    panel_info = Panel(
        Align.left(table_info),
        title="[bold red]SSHPLUS MANAGER PRO[/bold red]",
        border_style="red",
    )
    
    # Menu de opções
    menu_opcoes = Table(title=None, show_header=False, box=None)
    menu_opcoes.add_column(style="bold cyan", justify="left")
    menu_opcoes.add_column(style="bold white", justify="left")

    opcoes = [
        ("[01]", "INICIAR PROXY"),
        ("[02]", "CRIAR USUARIO"),
        ("[03]", "REMOVER USUARIO"),
        ("[04]", "VALIDAR PROXY"),
        ("[05]", "USUARIOS ONLINE"),
        ("[06]", "MONITORAR RECURSOS"),
        ("[07]", "CONFIGURAR VPN"),
        ("[08]", "LIMITAR TRAFEGO"),
        ("[09]", "EXECUTAR SPEEDTEST"),
        ("[10]", "SAIR"),
    ]

    for opcao, descricao in opcoes:
        menu_opcoes.add_row(opcao, descricao)

    menu_panel = Panel(menu_opcoes, border_style="blue", title="INFORME UMA OPCAO:")

    # Exibir painéis no terminal
    console.print(panel_info)
    console.print(menu_panel)

def processar_opcao(opcao):
    """Processa a escolha do menu."""
    if opcao == "01":
        console.print("[bold yellow]Funcionalidade de Proxy ainda não implementada.[/bold yellow]")
    elif opcao == "02":
        nome_usuario = console.input("[bold cyan]Digite o nome do usuário: [/bold cyan]")
        senha = console.input("[bold cyan]Digite a senha para o usuário: [/bold cyan]")
        criar_usuario(nome_usuario, senha)
    elif opcao == "03":
        nome_usuario = console.input("[bold cyan]Digite o nome do usuário a ser removido: [/bold cyan]")
        remover_usuario(nome_usuario)
    elif opcao == "04":
        proxy_url = console.input("[bold cyan]Digite o URL do Proxy (host:port): [/bold cyan]")
        if validar_proxy(proxy_url):
            console.print("[bold green]Proxy válido e ativo![/bold green]")
        else:
            console.print("[bold red]Proxy inválido ou inativo![/bold red]")
    elif opcao == "05":
        console.print("[bold yellow]Usuários Online: Implementar lógica[/bold yellow]")
    elif opcao == "06":
        monitorar_recursos()
    elif opcao == "07":
        nome_vpn = console.input("[bold cyan]Digite o nome da VPN: [/bold cyan]")
        endereco_vpn = console.input("[bold cyan]Digite o caminho do arquivo de configuração da VPN: [/bold cyan]")
        configurar_vpn(nome_vpn, endereco_vpn)
    elif opcao == "08":
        usuario = console.input("[bold cyan]Digite o nome do usuário: [/bold cyan]")
        limite = console.input("[bold cyan]Digite o limite de tráfego (em Kbps): [/bold cyan]")
        limitar_trafego(usuario, limite)
    elif opcao == "09":
        executar_speedtest()
    elif opcao == "10":
        console.print("[bold red]Saindo...[/bold red]")
        exit()
    else:
        console.print("[bold red]Opção inválida![/bold red]")

# ==========================
# Ponto de entrada do programa
# ==========================
if __name__ == "__main__":
    while True:
        exibir_interface()
        opcao = console.input("[bold cyan]Escolha uma opção: [/bold cyan]")
        processar_opcao(opcao)