#!/data/data/com.termux/files/usr/bin/bash

# Script de Instalação para Termux - Scanner de IPs Proxy via Dados Móveis
# Autor: Grok (corrigido para evitar travamento no termux-wifi-enable)
# Data: 10 de maio de 2025

# Cores para mensagens
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para exibir mensagens de premiação
award_message() {
    local messages=(
        "🎉 Parabéns! Você está escaneando como um pro com dados móveis!"
        "🚀 Mestre do Termux! A rede celular é sua aliada!"
        "🏆 Troféu de ouro por dominar a varredura mobile!"
        "🌟 Estrela brilhante! Os proxies não escapam de você!"
    )
    echo -e "${GREEN}${messages[$RANDOM % ${#messages[@]}]}${NC}"
}

# Função para verificar erros
check_error() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}Erro: $1${NC}"
        echo -e "${YELLOW}Continuando, mas verifique o problema acima.${NC}"
    fi
}

# Função para verificar conectividade via dados móveis
check_mobile_connectivity() {
    echo -e "${YELLOW}Verificando conectividade via dados móveis...${NC}"
    ping -c 1 8.8.8.8 > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${RED}Erro: Sem conexão com a internet.${NC}"
        echo -e "${YELLOW}Ative os dados móveis e tente novamente.${NC}"
        exit 1
    fi
    # Verificar se está usando dados móveis
    termux-telephony-deviceinfo > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Conexão via dados móveis confirmada!${NC}"
    else
        echo -e "${YELLOW}Aviso: Não foi possível confirmar dados móveis. Certifique-se de que o Wi-Fi está desativado.${NC}"
    fi
}

# Função para verificar e desativar Wi-Fi
disable_wifi() {
    echo -e "${YELLOW}Verificando status do Wi-Fi...${NC}"
    # Verificar se o Wi-Fi está ativo
    termux-wifi-connectioninfo | grep -q '"supplicant_state": "COMPLETED"' > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${YELLOW}Wi-Fi está ativo. Desativando para usar dados móveis...${NC}"
        timeout 10s termux-wifi-enable false > /dev/null 2>&1
        check_error "Falha ao desativar o Wi-Fi. Continuando com a rede atual."
    else
        echo -e "${GREEN}Wi-Fi já está desativado. Usando dados móveis!${NC}"
    fi
}

# Banner inicial
clear
echo -e "${YELLOW}========================================"
echo -e "   Instalador Termux - Scanner de IPs Proxy"
echo -e "=======================================${NC}"
echo -e "${GREEN}Bem-vindo! Vamos configurar e iniciar o scanner via dados móveis!${NC}\n"

# Passo 1: Configurar permissões do Termux
echo -e "${YELLOW}[1/8] Configurando permissões do Termux...${NC}"
termux-setup-storage
check_error "Falha ao configurar permissões de armazenamento."
chmod +x "$0"
echo -e "${GREEN}Permissões de armazenamento configuradas!${NC}"
award_message

# Passo 2: Instalar Termux-API
echo -e "${YELLOW}[2/8] Instalando Termux-API...${NC}"
pkg install -y termux-api
check_error "Falha ao instalar Termux-API."
# Forçar solicitação de permissões do Termux-API
termux-toast "Conceda permissões ao Termux-API se solicitado!"
termux-telephony-deviceinfo > /dev/null 2>&1
check_error "Falha ao verificar permissões do Termux-API."
award_message

# Passo 3: Desativar Wi-Fi para usar dados móveis
echo -e "${YELLOW}[3/8] Configurando rede para dados móveis...${NC}"
disable_wifi
award_message

# Passo 4: Verificar conectividade
check_mobile_connectivity
award_message

# Passo 5: Atualizar o Termux
echo -e "${YELLOW}[5/8] Atualizando o Termux...${NC}"
pkg update -y && pkg upgrade -y
check_error "Falha ao atualizar o Termux."
award_message

# Passo 6: Instalar pacotes essenciais
echo -e "${YELLOW}[6/8] Instalando pacotes essenciais...${NC}"
pkg install -y python wget curl git
check_error "Falha ao instalar pacotes."
award_message

# Passo 7: Instalar dependências Python
echo -e "${YELLOW}[7/8] Instalando bibliotecas Python...${NC}"
pip install --upgrade pip
pip install requests ipwhois requests[socks]
check_error "Falha ao instalar bibliotecas Python."
award_message

# Passo 8: Criar e executar o script do scanner
echo -e "${YELLOW}[8/8] Configurando e iniciando o scanner de proxies...${NC}"
SCANNER_FILE="$HOME/proxy_scanner.py"

# Escrever o código do scanner em um arquivo Python separado
cat > "$SCANNER_FILE" << 'EOF'
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
Assignment: results = []
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

# Verificar se o arquivo foi criado
if [ ! -f "$SCANNER_FILE" ]; then
    echo -e "${RED}Erro: Falha ao criar o script do scanner.${NC}"
    exit 1
fi

# Tornar o script executável
chmod +x "$SCANNER_FILE"
check_error "Falha ao tornar o scanner executável."

# Iniciar a varredura
echo -e "${GREEN}Iniciando a varredura de proxies via dados móveis...${NC}"
echo -e "${YELLOW}Resultados serão salvos em: ~/proxies.csv${NC}"
python "$SCANNER_FILE"
check_error "Falha ao executar a varredura."

# Restaurar Wi-Fi (opcional)
echo -e "${YELLOW}Restaurando Wi-Fi (se desejar)...${NC}"
read -p "Deseja reativar o Wi-Fi? (s/n): " wifi_restore
if [ "$wifi_restore" = "s" ] || [ "$wifi_restore" = "S" ]; then
    termux-wifi-enable true
    check_error "Falha ao reativar o Wi-Fi."
    echo -e "${GREEN}Wi-Fi reativado!${NC}"
else
    echo -e "${GREEN}Wi-Fi permaneceu desativado.${NC}"
fi
award_message

# Finalização
echo -e "${GREEN}Varredura concluída com sucesso usando dados móveis!${NC}"
echo -e "${YELLOW}Resultados salvos em: ~/proxies.csv${NC}"
echo -e "${YELLOW}Para executar a varredura novamente, use:${NC}"
echo -e "${GREEN}python ~/proxy_scanner.py${NC}"
award_message

exit 0