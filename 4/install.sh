#!/data/data/com.termux/files/usr/bin/bash

# Script de instalação para o Turbo Proxy Scanner no Termux
SCRIPT_URL="https://raw.githubusercontent.com/sofrenoob/Gggggg/main/4/proxy_scanner.sh"
SCRIPT_NAME="proxy_scanner.sh"
INSTALL_DIR="$HOME/proxy_scanner"
LOG_FILE="$HOME/install_log.txt"

# Função para log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Iniciar log
> "$LOG_FILE"
log "Iniciando instalação do Turbo Proxy Scanner..."

# 1. Atualizar Termux
log "Atualizando pacotes do Termux..."
pkg update -y && pkg upgrade -y || {
    log "Erro ao atualizar pacotes. Verifique sua conexão."
    exit 1
}

# 2. Configurar permissões de armazenamento
log "Configurando permissões de armazenamento..."
termux-setup-storage || {
    log "Erro ao configurar armazenamento. Execute 'termux-setup-storage' manualmente."
    exit 1
}

# 3. Instalar dependências
log "Instalando dependências (curl, whois, nmap, gzip)..."
for pkg in curl whois nmap gzip; do
    if ! command -v "$pkg" >/dev/null; then
        log "Instalando $pkg..."
        pkg install "$pkg" -y || {
            log "Erro ao instalar $pkg."
            exit 1
        }
    else
        log "$pkg já está instalado."
    fi
done

# 4. Criar diretório de instalação
log "Criando diretório $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR" || {
    log "Erro ao criar diretório $INSTALL_DIR."
    exit 1
}

# 5. Baixar o script principal
log "Baixando $SCRIPT_NAME de $SCRIPT_URL..."
curl -s -L "$SCRIPT_URL" -o "$INSTALL_DIR/$SCRIPT_NAME" || {
    log "Erro ao baixar $SCRIPT_NAME. Verifique o URL ou sua conexão."
    exit 1
}

# 6. Verificar se o script foi baixado
if [ ! -f "$INSTALL_DIR/$SCRIPT_NAME" ]; then
    log "Erro: $SCRIPT_NAME não foi baixado."
    exit 1
fi

# 7. Configurar permissões de execução
log "Configurando permissões para $SCRIPT_NAME..."
chmod +x "$INSTALL_DIR/$SCRIPT_NAME" || {
    log "Erro ao configurar permissões."
    exit 1
}

# 8. Instruções finais
log "Instalação concluída com sucesso!"
echo "=====================================" | tee -a "$LOG_FILE"
echo "Para executar o Turbo Proxy Scanner:" | tee -a "$LOG_FILE"
echo "1. Ative os dados móveis e desative o Wi-Fi." | tee -a "$LOG_FILE"
echo "2. Navegue até o diretório:" | tee -a "$LOG_FILE"
echo "   cd $INSTALL_DIR" | tee -a "$LOG_FILE"
echo "3. Execute o script:" | tee -a "$LOG_FILE"
echo "   ./$SCRIPT_NAME" | tee -a "$LOG_FILE"
echo "=====================================" | tee -a "$LOG_FILE"
echo "Logs de instalação: $LOG_FILE" | tee -a "$LOG_FILE"