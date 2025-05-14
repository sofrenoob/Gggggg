#!/bin/bash

# Caminho do SoftEther
SOFTETHER_DIR="/usr/local/vpnserver"
VPNCMD="$SOFTETHER_DIR/vpncmd"
HUB_NAME="VPN"  # Nome padrão do Virtual Hub (ajuste se necessário)
HUB_PASSWORD=""  # Senha do Hub (deixe vazio se não configurada, ou ajuste)

# Função para verificar se o SoftEther está instalado
check_softether() {
    if [ ! -f "$VPNCMD" ]; then
        echo "SoftEther VPN Server não encontrado em $SOFTETHER_DIR!"
        echo "Deseja instalar o SoftEther agora? (s/n)"
        read -r install_choice
        if [ "$install_choice" = "s" ]; then
            install_softether
        else
            echo "Saindo... Instale o SoftEther primeiro."
            exit 1
        fi
    fi
}

# Função para instalar o SoftEther
install_softether() {
    echo "Baixando e instalando o SoftEther VPN Server..."
    sudo apt update
    sudo apt install -y build-essential gcc make zlib1g-dev libssl-dev libreadline-dev libncurses5-dev
    wget https://github.com/SoftEtherVPN/SoftEtherVPN_Stable/releases/download/v4.43-9799-beta/softether-vpnserver-v4.43-9799-beta-2023.08.31-linux-x64-64bit.tar.gz -O /tmp/softether.tar.gz
    tar xzvf /tmp/softether.tar.gz -C /tmp
    cd /tmp/vpnserver
    make
    sudo mv /tmp/vpnserver $SOFTETHER_DIR
    cd $SOFTETHER_DIR
    sudo chmod 600 *
    sudo chmod 700 vpnserver vpncmd
    sudo ./vpnserver start
    echo "SoftEther instalado! Configure o Virtual Hub e a senha do servidor, se necessário."
    echo "Use a opção 6 para configurar o Hub e a senha."
}

# Função para executar comandos vpncmd
run_vpncmd() {
    local cmd="$1"
    echo "Executando: $cmd"
    echo -e "\n1\n\n$HUB_PASSWORD\n$cmd\n" | $VPNCMD | grep -v "VPN Tools>"
}

# Função para verificar status do servidor
check_status() {
    if pgrep vpnserver > /dev/null; then
        echo "SoftEther VPN Server está ATIVO."
    else
        echo "SoftEther VPN Server está DESATIVADO."
    fi
    echo "Portas ativas:"
    run_vpncmd "ListenerList"
}

# Função para ativar/desativar o servidor
toggle_server() {
    echo "1. Ativar servidor"
    echo "2. Desativar servidor"
    echo "Escolha uma opção:"
    read -r choice
    case $choice in
        1)
            sudo $SOFTETHER_DIR/vpnserver start
            echo "Servidor ativado."
            ;;
        2)
            sudo $SOFTETHER_DIR/vpnserver stop
            echo "Servidor desativado."
            ;;
        *)
            echo "Opção inválida!"
            ;;
    esac
}

# Função para gerenciar portas
manage_ports() {
    echo "1. Adicionar nova porta"
    echo "2. Remover porta"
    echo "3. Listar portas"
    echo "Escolha uma opção:"
    read -r choice
    case $choice in
        1)
            echo "Digite a porta (ex.: 80, 443, 1194):"
            read -r port
            if [[ ! $port =~ ^[0-9]+$ ]] || [ $port -lt 1 ] || [ $port -gt 65535 ]; then
                echo "Porta inválida!"
                return
            fi
            run_vpncmd "ListenerCreate $port"
            echo "Porta $port adicionada."
            echo "Deseja abrir a porta $port no firewall? (s/n)"
            read -r open_firewall
            if [ "$open_firewall" = "s" ]; then
                sudo ufw allow $port/tcp
                echo "Porta $port aberta no firewall."
            fi
            ;;
        2)
            echo "Digite a porta para remover:"
            read -r port
            run_vpncmd "ListenerDelete $port"
            echo "Porta $port removida."
            echo "Deseja fechar a porta $port no firewall? (s/n)"
            read -r close_firewall
            if [ "$close_firewall" = "s" ]; then
                sudo ufw deny $port/tcp
                echo "Porta $port fechada no firewall."
            fi
            ;;
        3)
            run_vpncmd "ListenerList"
            ;;
        *)
            echo "Opção inválida!"
            ;;
    esac
}

# Função para gerenciar firewall
manage_firewall() {
    echo "1. Abrir porta no firewall"
    echo "2. Fechar porta no firewall"
    echo "3. Ver status do firewall"
    echo "Escolha uma opção:"
    read -r choice
    case $choice in
        1)
            echo "Digite a porta (ex.: 80, 443):"
            read -r port
            if [[ ! $port =~ ^[0-9]+$ ]] || [ $port -lt 1 ] || [ $port -gt 65535 ]; then
                echo "Porta inválida!"
                return
            fi
            sudo ufw allow $port/tcp
            echo "Porta $port aberta no firewall."
            ;;
        2)
            echo "Digite a porta:"
            read -r port
            sudo ufw deny $port/tcp
            echo "Porta $port fechada no firewall."
            ;;
        3)
            sudo ufw status
            ;;
        *)
            echo "Opção inválida!"
            ;;
    esac
}

# Função para gerenciar usuários
manage_users() {
    echo "1. Criar novo usuário"
    echo "2. Listar usuários"
    echo "3. Alterar senhas"
    echo "4. Excluir usuário"
    echo "Escolha uma opção:"
    read -r choice
    case $choice in
        1)
            echo "Digite o nome do usuário:"
            read -r username
            run_vpncmd "UserCreate $username"
            echo "Digite a senha para $username:"
            run_vpncmd "UserPasswordSet $username"
            echo "Usuário $username criado."
            ;;
        2)
            run_vpncmd "UserList"
            ;;
        3)
            echo "Digite o nome do usuário:"
            read -r username
            run_vpncmd "UserPasswordSet $username"
            echo "Senha de $username alterada."
            ;;
        4)
            echo "Digite o nome do usuário para excluir:"
            read -r username
            run_vpncmd "UserDelete $username"
            echo "Usuário $username excluído."
            ;;
        *)
            echo "Opção inválida!"
            ;;
    esac
}

# Função para configurar o Virtual Hub e senha inicial
setup_hub() {
    echo "Configurando o Virtual Hub '$HUB_NAME'..."
    run_vpncmd "HubCreate $HUB_NAME"
    echo "Digite uma senha para o Hub (ou deixe vazio):"
    read -r hub_pass
    if [ -n "$hub_pass" ]; then
        run_vpncmd "Hub $HUB_NAME"
        run_vpncmd "SetHubPassword $hub_pass"
        HUB_PASSWORD="$hub_pass"
        echo "Senha do Hub configurada."
    fi
    echo "Habilitando SecureNAT para redirecionamento de tráfego..."
    run_vpncmd "Hub $HUB_NAME"
    run_vpncmd "SecureNatEnable"
    echo "Virtual Hub '$HUB_NAME' configurado."
}

# Função para ver logs
view_logs() {
    echo "Exibindo os últimos 20 registros de log do servidor..."
    sudo tail -n 20 $SOFTETHER_DIR/server_log/*
}

# Menu principal
main_menu() {
    while true; do
        clear
        echo "====================================="
        echo " Gerenciador do Servidor SoftEther VPN"
        echo "====================================="
        check_status
        echo "-------------------------------------"
        echo "1. Ativar/Desativar servidor"
        echo "2. Gerenciar portas"
        echo "3. Gerenciar firewall"
        echo "4. Gerenciar usuários"
        echo "5. Ver logs"
        echo "6. Configurar Virtual Hub e senha"
        echo "7. Sair"
        echo "Escolha uma opção:"
        read -r choice
        case $choice in
            1) toggle_server ;;
            2) manage_ports ;;
            3) manage_firewall ;;
            4) manage_users ;;
            5) view_logs ;;
            6) setup_hub ;;
            7) echo "Saindo..."; exit 0 ;;
            *) echo "Opção inválida!" ;;
        esac
        echo "Pressione Enter para continuar..."
        read
    done
}

# Verificar se o script está sendo executado como root
if [ "$EUID" -ne 0 ]; then
    echo "Este script precisa ser executado como root (use sudo)."
    exit 1
fi

# Verificar instalação do SoftEther
check_softether

# Iniciar o menu principal
main_menu