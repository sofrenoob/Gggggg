#!/data/data/com.termux/files/usr/bin/bash

# Script de Instalação para Termux - Scanner de IPs Proxy com Permissões
# Autor: (adaptado para o usuário)
# Data: 10 de maio de 2025

# Cores para mensagens
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para exibir mensagens de premiação
award_message() {
    local messages=(
        "🎉 Parabéns! Você está pronto para dominar a varredura de proxies!"
        "🚀 Mestre do Termux! Sua jornada épica começou!"
        "🏆 Troféu de ouro por configurar o ambiente!"
        "🌟 Estrela brilhante! Os IPs não têm chance contra você!"
    )
    echo -e "${GREEN}${messages[$RANDOM % ${#messages[@]}]}${NC}"
}

# Função para verificar erros
check_error() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}Erro: $1${NC}"
        exit 1
    fi
}

# Função para verificar conectividade
check_connectivity() {
    echo -e "${YELLOW}Verificando conectividade com a internet...${NC}"
    ping -c 1 8.8.8.8 > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${RED}Erro: Sem conexão com a internet.${NC}"
        echo -e "${YELLOW}Conecte-se a uma rede Wi-Fi ou dados móveis e tente novamente.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Conexão OK!${NC}"
}

# Banner inicial
clear
echo -e "${YELLOW}========================================"
echo -e "   Instalador Termux - Scanner de IPs Proxy"
echo -e "=======================================${NC}"
echo -e "${GREEN}Bem-vindo! Vamos configurar e iniciar o scanner!${NC}\n"

# Passo 1: Configurar permissões do Termux
echo -e "${YELLOW}[1/7] Configurando permissões do Termux...${NC}"
termux-setup-storage
check_error "Falha ao configurar permissões de armazenamento."
# Garantir permissões de execução para scripts
chmod +x "$0"
echo -e "${GREEN}Permissões configuradas!${NC}"
award_message

# Passo 2: Verificar conectividade
check_connectivity
award_message

# Passo 3: Atualizar o Termux
echo -e "${YELLOW}[3/7] Atualizando o Termux...${NC}"
pkg update -y && pkg upgrade -y
check_error "Falha ao atualizar o Termux."
award_message

# Passo 4: Instalar pacotes essenciais
echo -e "${YELLOW}[4/7] Instalando pacotes essenciais...${NC}"
pkg install -y python wget curl git
check_error "Falha ao instalar pacotes."
award_message

# Passo 5: Instalar dependências Python
echo -e "${YELLOW}[5/7] Instalando bibliotecas Python...${NC}"
pip install --upgrade pip
pip install requests ipwhois requests[socks]
check_error "Falha ao instalar bibliotecas Python."
award_message

# Passo 6: Criar o script do scanner
echo -e "${YELLOW}[6/7] Configurando o scanner de proxies...${NC}"
SCANNER_FILE="/data/data/com.termux/files/home/proxy_scanner.py"

# Escrever o código do scanner no arquivo
cat << 'EOF' > "$SCANNER_FILE"
import requests
import socket
import concurrent.futures
from ipwhois import IPWhois
import csv
from typing import List, Dict

# Configurações
TEST_URL = "http://httpbin.org/ip"  # URL para testar proxies
PORTS = [80, 8080, 3128, 1080]     # Portas comuns de proxies
TIMEOUT = 5                        # Timeout para conexões
OUTPUT_FILE = "proxies.csv"        # Arquivo de saída

def is_port_open(ip: str, port: int) -> bool:
    """Verifica se uma porta está aberta em um IP."""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(TIMEOUT)
        result = sock.connect_ex((ip, port))
        sock.close()
        return result == 0
    except Exception:
        return False

def test_proxy(ip: str, port: int, protocol: str = "http") -> Dict:
    """Testa se um IP:porta funciona como proxy."""
    proxy_url = f"{protocol}://{ip}:{port}"
    proxies = {protocol: proxy_url}
    
    try:
        response = requests.get(TEST_URL, proxies=proxies, timeout=TIMEOUT)
        if response.status_code == 200:
            # Verificar origem do IP
            whois = IPWhois(ip)
            whois_result = whois.lookup_rdap()
            asn_description = whois_result.get("asn_description", "Desconhecido")
            
            return {
                "ip": ip,
                "port": port,
                "protocol": protocol,
                "status": "working",
                "operadora": asn_description
            }
    except Exception:
        return {
            "ip": ip,
            "port": port,
            "protocol": protocol,
            "status": "failed",
            "operadora": None
        }

def scan_ip(ip: str) -> List[Dict]:
    """Escaneia um IP em várias portas e testa como proxy."""
    results = []
    for port in PORTS:
        if is_port_open(ip, port):
            # Testar como proxy HTTP
            result = test_proxy(ip, port, "http")
            if result["status"] == "working":
                results.append(result)
            # Testar como proxy SOCKS (se aplicável)
            result = test_proxy(ip, port, "socks5")
            if result["status"] == "working":
                results.append(result)
    return results

def save_results(results: List[Dict]):
    """Salva os resultados em um arquivo CSV."""
    with open(OUTPUT_FILE, mode="a", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["ip", "port", "protocol", "status", "operadora"])
        if f.tell() == 0:
            writer.writeheader()
        writer.writerows(results)

def main(ip_range: List[str]):
    """Função principal para escanear uma lista de IPs."""
    valid_proxies = []
    
    with concurrent.futures.ThreadPoolExecutor(max_workers=20) as executor:
        # Escanear IPs em paralelo
        future_to_ip = {executor.submit(scan_ip, ip): ip for ip in ip_range}
        for future in concurrent.futures.as_completed(future_to_ip):
            ip = future_to_ip[future]
            try:
                results = future.result()
                if results:
                    valid_proxies.extend(results)
                    print(f"Proxy encontrado em {ip}: {results}")
            except Exception as e:
                print(f"Erro ao escanear {ip}: {e}")
    
    if valid_proxies:
        save_results(valid_proxies)
        print(f"Resultados salvos em {OUTPUT_FILE}")

if __name__ == "__main__":
    # Faixa de IPs de teste (substitua por IPs reais)
    ip_range = [f"104.28.0.{i}" for i in range(1, 10)]  # Exemplo com IPs da Cloudflare
    main(ip_range)
EOF

# Tornar o script executável
chmod +x "$SCANNER_FILE"
check_error "Falha ao configurar o scanner."
award_message

# Passo 7: Iniciar a varredura
echo -e "${YELLOW}[7/7] Iniciando a varredura de proxies...${NC}"
echo -e "${GREEN}A varredura está começando! Verifique o arquivo proxies.csv para os resultados.${NC}"
python "$SCANNER_FILE"
check_error "Falha ao executar a varredura."

# Finalização
echo -e "${GREEN}Varredura concluída com sucesso!${NC}"
echo -e "${YELLOW}Resultados salvos em: ~/proxies.csv${NC}"
award_message

exit 0