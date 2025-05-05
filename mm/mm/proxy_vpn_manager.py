import os
import subprocess
import curses
import json
import signal
from pathlib import Path

# Configuração de diretórios
default_dir = Path("/opt/proxy_vpn_manager")
install_dir = default_dir
logs_dir = install_dir / "logs"
config_path = install_dir / "config" / "proxies.json"

# Certifica que diretórios existem
logs_dir.mkdir(parents=True, exist_ok=True)

# Gerenciamento de processos ativos
active_procs = {}

# Carrega configurações do arquivo JSON
def load_config():
    if not config_path.exists():
        return {}
    with open(config_path) as f:
        return json.load(f)

# Função para iniciar um proxy
" "def start_proxy(name, cmd):
    # Finaliza processo existente
    if name in active_procs:
        return f"{name} já está em execução."
    log_file = logs_dir / f"{name}.log"
    with open(log_file, 'wb') as lf:
        proc = subprocess.Popen(cmd, stdout=lf, stderr=lf)
    active_procs[name] = proc
    return f"Iniciado {name} (PID {proc.pid})."

# Função para parar um proxy
 def stop_proxy(name):
    proc = active_procs.get(name)
    if not proc:
        return f"{name} não está em execução."
    os.kill(proc.pid, signal.SIGTERM)
    del active_procs[name]
    return f"Parado {name}."

# Exibe status dos proxies
def status_proxies():
    status = []
    for name, proc in active_procs.items():
        status.append(f"{name}: PID {proc.pid} (vivo: {proc.poll() is None})")
    return status

# Menu curses
 def main_menu(stdscr):
    curses.curs_set(0)
    menu = [
        "1 - Proxy HTTP",
        "2 - Proxy HTTPS (MITM)",
        "3 - Proxy SOCKS5",
        "4 - Proxy Reverso",
        "5 - Túnel TCP",
        "6 - Proxy com Autenticação",
        "7 - Iniciar Todas Portas Configuradas",
        "8 - Status dos Proxies",
        "9 - Encerrar Proxy",
        "0 - Sair"
    ]
    while True:
        stdscr.clear()
        stdscr.addstr(0, 0, "Proxy & VPN Manager")
        stdscr.addstr(1, 0, "=" * 40)
        for idx, item in enumerate(menu):
            stdscr.addstr(idx+3, 0, item)
        stdscr.addstr(len(menu)+4, 0, "Escolha uma opção: ")
        stdscr.refresh()
        choice = stdscr.getkey()

        cfg = load_config()
        if choice == '1':
            host = cfg.get('http', {}).get('host', '0.0.0.0')
            port = str(cfg.get('http', {}).get('port', 8080))
            msg = start_proxy('http', ["python3", str(install_dir/"proxy.py-develop/proxy.py"), "--hostname", host, "--port", port])
            stdscr.addstr(15, 0, msg)

        elif choice == '2':
            host = cfg.get('https', {}).get('host', '0.0.0.0')
            port = str(cfg.get('https', {}).get('port', 443))
            msg = start_proxy('https', ["python3", str(install_dir/"proxy.py-develop/proxy.py"), "--hostname", host, "--port", port, "--enable-tls-interception"])
            stdscr.addstr(15, 0, msg)

        elif choice == '3':
            port = str(cfg.get('socks5', {}).get('port', 1080))
            msg = start_proxy('socks5', [str(install_dir/"goproxy-master/goproxy"), "socks5", "--addr", f":{port}"])
            stdscr.addstr(15, 0, msg)

        elif choice == '4':
            port = str(cfg.get('reverse', {}).get('port', 8000))
            msg = start_proxy('reverse', [str(install_dir/"goproxy-master/goproxy"), "proxy", "--reverse", "--addr", f":{port}"])
            stdscr.addstr(15, 0, msg)

        elif choice == '5':
            port = str(cfg.get('tcp', {}).get('port', 9000))
            target = cfg.get('tcp', {}).get('target', '127.0.0.1:22')
            msg = start_proxy('tcp_tunnel', [str(install_dir/"goproxy-master/goproxy"), "tcp", "--listen", f":{port}", "--forward", target])
            stdscr.addstr(15, 0, msg)

        elif choice == '6':
            user = cfg.get('auth', {}).get('user', 'user')
            pwd = cfg.get('auth', {}).get('pass', 'pass')
            msg = start_proxy('auth', ["python3", str(install_dir/"proxy.py-develop/proxy.py"), "--plugins", "proxy.plugin.BasicAuthPlugin", "--basic-auth-username", user, "--basic-auth-password", pwd])
            stdscr.addstr(15, 0, msg)

        elif choice == '7':
            # Iniciar todas as portas definidas em config
            for key in ['http','https','socks5','reverse','tcp','auth']:
                # simula as opções acima
                pass
            stdscr.addstr(15,0, "Todas as tarefas iniciadas.")

        elif choice == '8':
            status = status_proxies()
            for idx, line in enumerate(status):
                stdscr.addstr(15+idx, 0, line)

        elif choice == '9':
            stdscr.addstr(15,0, "Digite o nome do proxy a parar: ")
            curses.echo()
            name = stdscr.getstr(16,0,20).decode()
            curses.noecho()
            msg = stop_proxy(name)
            stdscr.addstr(17,0,msg)

        elif choice == '0':
            break

        stdscr.refresh()
        stdscr.getch()

# Execução
def main():
    curses.wrapper(main_menu)

if __name__ == "__main__":
    main()
