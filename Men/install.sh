#!/bin/bash

# Definições
PROXY_PY_URL="https://example.com/proxy.py"       # Substitua pelo link real do proxy.py
PROXY_MENU_URL="https://example.com/proxy_menu.py" # Substitua pelo link real do proxy_menu.py
INSTALL_DIR="/opt/proxy-manager"
LOG_FILE="/var/log/proxy-manager-install.log"

# Funções Auxiliares
log() {
    echo "$1" | tee -a $LOG_FILE
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "Este script deve ser executado como root. Use 'sudo ./install.sh'."
        exit 1
    fi
}

create_directory() {
    log "Criando diretório de instalação em $INSTALL_DIR..."
    mkdir -p $INSTALL_DIR
    chmod 755 $INSTALL_DIR
    log "Diretório criado."
}

download_files() {
    log "Baixando arquivos necessários..."

    log "Baixando proxy.py..."
    curl -o "$INSTALL_DIR/proxy.py" "$PROXY_PY_URL"
    if [[ $? -ne 0 ]]; then
        log "Erro ao baixar proxy.py. Verifique o link e tente novamente."
        exit 1
    fi

    log "Baixando proxy_menu.py..."
    curl -o "$INSTALL_DIR/proxy_menu.py" "$PROXY_MENU_URL"
    if [[ $? -ne 0 ]]; then
        log "Erro ao baixar proxy_menu.py. Verifique o link e tente novamente."
        exit 1
    fi

    log "Arquivos baixados com sucesso."
}

set_permissions() {
    log "Configurando permissões..."
    chmod +x "$INSTALL_DIR/proxy.py"
    chmod +x "$INSTALL_DIR/proxy_menu.py"
    log "Permissões configuradas."
}

create_shortcut() {
    log "Criando atalhos para execução..."
    ln -sf "$INSTALL_DIR/proxy.py" /usr/local/bin/proxy
    ln -sf "$INSTALL_DIR/proxy_menu.py" /usr/local/bin/proxy-menu
    log "Atalhos criados: 'proxy' e 'proxy-menu'."
}

show_congratulations() {
    log "Instalação concluída com sucesso! 🎉"
    log "Você pode iniciar o proxy com:"
    log "  proxy-menu  # Para acessar o menu de configurações"
    log "  proxy       # Para iniciar o proxy diretamente"
    log "Divirta-se utilizando o Proxy Manager! 🚀"
}

# Script Principal
log "Iniciando instalação do Proxy Manager..."
check_root
create_directory
download_files
set_permissions
create_shortcut
show_congratulations