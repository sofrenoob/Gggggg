#!/bin/bash

# Nome do projeto
NOME_PROJETO="Gerenciador de Configurações"
MENU_URL="https://raw.githubusercontent.com/sofrenoob/Gggggg/main/4/menu_principal" # Link direto para o menu_principal no GitHub
MENU_LOCAL="/usr/local/bin/menu_principal"

# Função para instalar dependências e configurar serviços
instalar_dependencias() {
    echo "==============================="
    echo "   INSTALAÇÃO DE DEPENDÊNCIAS"
    echo "==============================="

    # Atualizar repositórios e pacotes
    echo "Atualizando repositórios e pacotes..."
    sudo apt update -y && sudo apt upgrade -y

    # Instalar pacotes essenciais
    echo "Instalando pacotes essenciais..."
    sudo apt install -y git curl iptables lsof build-essential cmake net-tools iproute2 stunnel4

    # Instalar BADVPN
    echo "Instalando BADVPN..."
    if ! command -v badvpn-udpgw &> /dev/null; then
        git clone https://github.com/ambrop72/badvpn.git /tmp/badvpn
        cd /tmp/badvpn || exit
        cmake . -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1
        make
        sudo cp badvpn-udpgw /usr/bin/
        cd || exit
        sudo rm -rf /tmp/badvpn
        echo "BADVPN instalado com sucesso!"
    else
        echo "BADVPN já está instalado."
    fi

    # Instalar V2Ray
    echo "Instalando V2Ray..."
    if ! command -v v2ray &> /dev/null; then
        bash <(curl -L -s https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
        echo "V2Ray instalado com sucesso!"
    else
        echo "V2Ray já está instalado."
    fi

    # Instalar SlowDNS
    echo "Instalando SlowDNS..."
    if ! command -v slowdns &> /dev/null; then
        sudo curl -o /usr/bin/slowdns https://example.com/slowdns-binary
        sudo chmod +x /usr/bin/slowdns
        echo "SlowDNS instalado com sucesso!"
    else
        echo "SlowDNS já está instalado."
    fi

    # Configurar Stunnel4
    echo "Configurando Stunnel4..."
    sudo systemctl enable stunnel4
    sudo systemctl start stunnel4
    echo "Stunnel4 configurado com sucesso!"

    echo "Todas as dependências foram instaladas e configuradas com sucesso!"
}

# Função para instalar e configurar o menu
instalar_menu_principal() {
    echo "==============================="
    echo "   INSTALAÇÃO DO MENU"
    echo "==============================="

    # Fazer download do menu_principal
    echo "Baixando o menu_principal..."
    sudo curl -o "$MENU_PRINCIPAL_LOCAL" "$MENU_PRINCIPAL_URL"
    sudo chmod +x "$MENU_PRINCIPAL_LOCAL"

    echo "menu_principal instalado com sucesso! Você pode executá-lo com o comando: menu_principal"
}

# Função principal do script
instalar_tudo() {
    instalar_dependencias
    instalar_menu_principal

    echo "==============================="
    echo "   INSTALAÇÃO CONCLUÍDA"
    echo "==============================="

    # Executar automaticamente o menu_principal
    echo "Executando o menu_principal..."
    "$MENU_PRINCIPAL_LOCAL"
}

# Executar a função principal
instalar_tudo