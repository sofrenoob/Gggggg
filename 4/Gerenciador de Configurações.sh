#!/bin/bash

# Nome do projeto
NOME_PROJETO="Gerenciador de Configurações"
LOG_FILE="/var/log/gerenciador_configuracoes.log"

# Função para registrar logs
log_action() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

# Função para exibir o menu principal
menu_principal() {
    while true; do
        clear
        echo "==============================="
        echo "   $NOME_PROJETO - MENU PRINCIPAL"
        echo "==============================="
        echo "1. Criar Usuários"
        echo "2. Conexões"
        echo "3. BADVPN"
        echo "4. Informações do Sistema"
        echo "5. Balanceamento de Carga"
        echo "6. Sair"
        echo "==============================="
        read -p "Digite a opção desejada: " opcao

        case $opcao in
            1) menu_criar_usuarios ;;
            2) menu_conexoes ;;
            3) configurar_badvpn ;;
            4) info_sistema ;;
            5) menu_balanceamento ;;
            6) sair ;;
            *) 
                echo "Opção inválida! Por favor, tente novamente."
                sleep 2
                ;;
        esac
    done
}

#!/bin/bash

# Nome do arquivo de log
LOG_FILE="/var/log/gerenciador_configuracoes.log"

# Função para registrar ações no log
log_action() {
    local mensagem="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $mensagem" >> "$LOG_FILE"
}

# Submenu de Criar Usuários
menu_criar_usuarios() {
    clear
    echo "==============================="
    echo "   GERENCIAR USUÁRIOS"
    echo "==============================="
    echo "1. Adicionar Usuário com Expiração"
    echo "2. Alterar Senha de Usuário"
    echo "3. Alterar Limite de Conexões"
    echo "4. Ver Usuários Online"
    echo "5. Remover Usuários Expirados"
    echo "6. Backup de Usuários"
    echo "7. Voltar"
    echo "==============================="
    read -p "Digite a opção desejada: " opcao

    case $opcao in
        1) adicionar_usuario ;;
        2) alterar_senha ;;
        3) alterar_limite ;;
        4) ver_online ;;
        5) remover_expirados ;;
        6) backup_usuarios ;;
        7) menu_principal ;;
        *) echo "Opção inválida!"; sleep 2; menu_criar_usuarios ;;
    esac
}

# Funções relacionadas a usuários
adicionar_usuario() {
    clear
    echo "==============================="
    echo "   ADICIONAR USUÁRIO"
    echo "==============================="
    read -p "Digite o nome do usuário: " usuario
    read -p "Digite a senha para o usuário: " senha
    read -p "Digite a data de expiração (YYYY-MM-DD): " expiracao
    read -p "Digite o limite de conexões para o usuário: " limite

    sudo useradd -e "$expiracao" -m "$usuario"
    echo "$usuario:$senha" | sudo chpasswd
    echo "$usuario:$limite" | sudo tee -a /etc/limites_usuarios.txt > /dev/null

    log_action "Usuário $usuario criado com expiração $expiracao e limite de conexões $limite."
    echo "Usuário $usuario criado com sucesso!"
    sleep 3
    menu_criar_usuarios
}

alterar_senha() {
    clear
    echo "==============================="
    echo "   ALTERAR SENHA DO USUÁRIO"
    echo "==============================="
    read -p "Digite o nome do usuário: " usuario
    read -p "Digite a nova senha: " senha
    echo "$usuario:$senha" | sudo chpasswd

    log_action "Senha alterada para o usuário $usuario."
    echo "Senha alterada com sucesso para o usuário $usuario!"
    sleep 3
    menu_criar_usuarios
}

alterar_limite() {
    clear
    echo "==============================="
    echo "   ALTERAR LIMITE DE CONEXÕES"
    echo "==============================="
    read -p "Digite o nome do usuário: " usuario
    read -p "Digite o novo limite de conexões: " limite

    if grep -q "$usuario" /etc/limites_usuarios.txt; then
        sudo sed -i "s/$usuario:.*/$usuario:$limite/" /etc/limites_usuarios.txt
        log_action "Limite de conexões alterado para o usuário $usuario. Novo limite: $limite."
        echo "Limite de conexões atualizado para o usuário $usuario!"
    else
        echo "Usuário não encontrado!"
    fi
    sleep 3
    menu_criar_usuarios
}

ver_online() {
    clear
    echo "==============================="
    echo "   USUÁRIOS ONLINE"
    echo "==============================="
    who
    log_action "Exibido usuários online."
    sleep 5
    menu_criar_usuarios
}

remover_expirados() {
    clear
    echo "==============================="
    echo "   REMOVER USUÁRIOS EXPIRADOS"
    echo "==============================="
    hoje=$(date +%Y-%m-%d)
    for usuario in $(cut -d: -f1 /etc/shadow); do
        expiracao=$(sudo chage -l "$usuario" | grep "Account expires" | awk '{print $4}')
        if [[ "$expiracao" < "$hoje" ]] && [[ "$expiracao" != "never" ]]; then
            sudo userdel -r "$usuario"
            sudo sed -i "/^$usuario:/d" /etc/limites_usuarios.txt
            log_action "Usuário $usuario removido por expiração."
            echo "Usuário $usuario removido."
        fi
    done
    sleep 3
    menu_criar_usuarios
}

backup_usuarios() {
    clear
    echo "==============================="
    echo "   BACKUP DE USUÁRIOS"
    echo "==============================="
    sudo cp /etc/passwd /etc/passwd.bak
    sudo cp /etc/shadow /etc/shadow.bak
    sudo cp /etc/limites_usuarios.txt /etc/limites_usuarios.bak
    log_action "Backup de usuários realizado."
    echo "Backup concluído com sucesso!"
    sleep 3
    menu_criar_usuarios
}

# Função para o menu principal
menu_principal() {
    echo "Menu Principal - ainda não implementado."
    exit 0
}

# Início do script
menu_criar_usuarios

}
# Submenu de Conexões
menu_conexoes() {
    clear
    echo "==============================="
    echo "   $NOME_PROJETO - CONEXÕES"
    echo "==============================="
    echo "1. Configurar Proxy"
    echo "2. Configurar Proxy WebSocket"
    echo "3. Configurar SSL Tunnel"
    echo "4. Configurar V2Ray"
    echo "5. Configurar XRay"
    echo "6. Configurar SlowDNS"
    echo "7. Voltar"
    echo "==============================="
    read -p "Digite a opção desejada: " opcao

    case $opcao in
        1) configurar_proxy ;;
        2) configurar_proxy_websocket ;;
        3) configurar_ssl_tunnel ;;
        4) configurar_v2ray ;;
        5) configurar_xray ;;
        6) configurar_slowdns ;;
        7) menu_principal ;;
        *) echo "Opção inválida!"; sleep 2; menu_conexoes ;;
    esac
}

# Função para configurar Proxy
# Função para configurar Proxy
configurar_proxy() {
    clear
    echo "==============================="
    echo "   CONFIGURAR PROXY"
    echo "==============================="
    echo "1. Iniciar Proxy"
    echo "2. Parar Proxy"
    echo "3. Configurar Porta do Proxy"
    echo "4. Configurar Automaticamente o Serviço Proxy"
    echo "5. Voltar"
    echo "==============================="
    read -p "Escolha uma opção: " opcao

    case $opcao in
        1) iniciar_proxy ;;
        2) parar_proxy ;;
        3) configurar_porta_proxy ;;
        4) configurar_servico_proxy ;;
        5) menu_conexoes ;;
        *) echo "Opção inválida!"; sleep 2; configurar_proxy ;;
    esac
}
# Função para configurar automaticamente o serviço Proxy
configurar_servico_proxy() {
    echo "Configurando automaticamente o serviço Proxy..."

    # Passo 1: Criar o arquivo de configuração do Proxy
    arquivo_config="/etc/proxy/config.conf"
    if [ ! -f "$arquivo_config" ]; then
        sudo mkdir -p /etc/proxy
        echo "Port=8080" | sudo tee "$arquivo_config" > /dev/null
        log_action "Arquivo de configuração do Proxy criado em $arquivo_config com a porta padrão 8080."
        echo "Arquivo de configuração criado com a porta padrão 8080."
    else
        log_action "Arquivo de configuração do Proxy já existente em $arquivo_config."
        echo "Arquivo de configuração já existe. Nenhuma ação necessária."
    fi

    # Passo 2: Criar o arquivo de serviço do systemd
    arquivo_servico="/etc/systemd/system/proxy.service"
    if [ ! -f "$arquivo_servico" ]; then
        sudo tee "$arquivo_servico" > /dev/null <<EOL
[Unit]
Description=Proxy Customizado
After=network.target

[Service]
ExecStart=/usr/bin/nc -lk -p \$(grep 'Port=' /etc/proxy/config.conf | cut -d= -f2)
Restart=always
User=nobody
Group=nogroup

[Install]
WantedBy=multi-user.target
EOL
        log_action "Arquivo de serviço do Proxy criado em $arquivo_servico."
        echo "Arquivo de serviço criado em $arquivo_servico."
    else
        log_action "Arquivo de serviço do Proxy já existente em $arquivo_servico."
        echo "Arquivo de serviço já existe. Nenhuma ação necessária."
    fi

    # Passo 3: Recarregar o systemd e habilitar o serviço
    sudo systemctl daemon-reload
    sudo systemctl enable proxy.service
    log_action "Serviço Proxy habilitado no systemd."
    echo "Serviço Proxy configurado e habilitado com sucesso!"

    sleep 3
    configurar_proxy
}

# Função para iniciar o serviço Proxy
iniciar_proxy() {
    echo "Iniciando Proxy..."
    if sudo systemctl start proxy.service; then
        log_action "Serviço Proxy iniciado com sucesso."
        echo "Proxy iniciado com sucesso!"
    else
        log_action "Erro ao iniciar o serviço Proxy."
        echo "Erro ao iniciar o Proxy. Verifique o serviço."
    fi
    sleep 3
    configurar_proxy
}

# Função para parar o serviço Proxy
parar_proxy() {
    echo "Parando Proxy..."
    if sudo systemctl stop proxy.service; then
        log_action "Serviço Proxy parado com sucesso."
        echo "Proxy parado com sucesso!"
    else
        log_action "Erro ao parar o serviço Proxy."
        echo "Erro ao parar o Proxy. Verifique o serviço."
    fi
    sleep 3
    configurar_proxy
}

# Função para configurar a porta do Proxy
configurar_porta_proxy() {
    echo "==============================="
    echo "   CONFIGURAR PORTA DO PROXY"
    echo "==============================="
    read -p "Digite a nova porta para o Proxy: " nova_porta

    # Caminho do arquivo de configuração do Proxy
    arquivo_config="/etc/proxy/config.conf"

    # Atualizar a porta no arquivo de configuração
    if sudo sed -i "s/^Port=.*/Port=$nova_porta/" "$arquivo_config"; then
        log_action "Porta do Proxy configurada para $nova_porta."
        echo "Porta configurada com sucesso para $nova_porta."

        # Reiniciar o serviço Proxy para aplicar a nova configuração
        if sudo systemctl restart proxy.service; then
            log_action "Serviço Proxy reiniciado após alteração de porta."
            echo "Proxy reiniciado com sucesso para aplicar a nova porta."
        else
            log_action "Erro ao reiniciar o serviço Proxy após alteração de porta."
            echo "Erro ao reiniciar o Proxy. Verifique a configuração."
        fi
    else
        log_action "Erro ao atualizar a porta no arquivo de configuração do Proxy."
        echo "Erro ao configurar a nova porta. Verifique o arquivo de configuração."
    fi
    sleep 3
    configurar_proxy
}

# Log de ações realizadas no script
log_action() {
    local mensagem="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $mensagem" >> /var/log/gerenciador_configuracoes.log
}

# Função para configurar Proxy WebSocket
configurar_proxy_websocket() {
    clear
    echo "==============================="
    echo "   CONFIGURAR PROXY WEBSOCKET"
    echo "==============================="
    echo "1. Iniciar Proxy WebSocket"
    echo "2. Parar Proxy WebSocket"
    echo "3. Configurar Porta do Proxy WebSocket"
    echo "4. Configurar Automaticamente o Serviço WebSocket"
    echo "5. Voltar"
    echo "==============================="
    read -p "Escolha uma opção: " opcao

    case $opcao in
        1) iniciar_proxy_websocket ;;
        2) parar_proxy_websocket ;;
        3) configurar_porta_proxy_websocket ;;
        4) configurar_servico_websocket ;;
        5) menu_conexoes ;;
        *) echo "Opção inválida!"; sleep 2; configurar_proxy_websocket ;;
    esac
}

# Função para configurar automaticamente o serviço WebSocket
configurar_servico_websocket() {
    echo "Configurando automaticamente o serviço Proxy WebSocket..."

    # Passo 1: Criar o arquivo de configuração do WebSocket
    arquivo_config="/etc/websocket/config.conf"
    if [ ! -f "$arquivo_config" ]; then
        sudo mkdir -p /etc/websocket
        echo "Port=8081" | sudo tee "$arquivo_config" > /dev/null
        log_action "Arquivo de configuração do WebSocket criado em $arquivo_config com a porta padrão 8081."
        echo "Arquivo de configuração criado com a porta padrão 8081."
    else
        log_action "Arquivo de configuração do WebSocket já existente em $arquivo_config."
        echo "Arquivo de configuração já existe. Nenhuma ação necessária."
    fi

    # Passo 2: Criar o arquivo de serviço do systemd
    arquivo_servico="/etc/systemd/system/websocket.service"
    if [ ! -f "$arquivo_servico" ]; then
        sudo tee "$arquivo_servico" > /dev/null <<EOL
[Unit]
Description=Proxy WebSocket Customizado
After=network.target

[Service]
ExecStart=/usr/bin/python3 -m http.server \$(grep 'Port=' /etc/websocket/config.conf | cut -d= -f2) --bind 0.0.0.0
Restart=always
User=nobody
Group=nogroup

[Install]
WantedBy=multi-user.target
EOL
        log_action "Arquivo de serviço do WebSocket criado em $arquivo_servico."
        echo "Arquivo de serviço criado em $arquivo_servico."
    else
        log_action "Arquivo de serviço do WebSocket já existente em $arquivo_servico."
        echo "Arquivo de serviço já existe. Nenhuma ação necessária."
    fi

    # Passo 3: Recarregar o systemd e habilitar o serviço
    sudo systemctl daemon-reload
    sudo systemctl enable websocket.service
    log_action "Serviço WebSocket habilitado no systemd."
    echo "Serviço WebSocket configurado e habilitado com sucesso!"

    sleep 3
    configurar_proxy_websocket
}

# Função para iniciar o serviço WebSocket
iniciar_proxy_websocket() {
    echo "Iniciando Proxy WebSocket..."
    if sudo systemctl start websocket.service; then
        log_action "Serviço WebSocket iniciado com sucesso."
        echo "Proxy WebSocket iniciado com sucesso!"
    else
        log_action "Erro ao iniciar o serviço WebSocket."
        echo "Erro ao iniciar o Proxy WebSocket. Verifique o serviço."
    fi
    sleep 3
    configurar_proxy_websocket
}

# Função para parar o serviço WebSocket
parar_proxy_websocket() {
    echo "Parando Proxy WebSocket..."
    if sudo systemctl stop websocket.service; then
        log_action "Serviço WebSocket parado com sucesso."
        echo "Proxy WebSocket parado com sucesso!"
    else
        log_action "Erro ao parar o serviço WebSocket."
        echo "Erro ao parar o Proxy WebSocket. Verifique o serviço."
    fi
    sleep 3
    configurar_proxy_websocket
}

# Função para configurar a porta do WebSocket
configurar_porta_proxy_websocket() {
    echo "==============================="
    echo "   CONFIGURAR PORTA DO PROXY WEBSOCKET"
    echo "==============================="
    read -p "Digite a nova porta para o Proxy WebSocket: " nova_porta

    # Caminho do arquivo de configuração do WebSocket
    arquivo_config="/etc/websocket/config.conf"

    # Atualizar a porta no arquivo de configuração
    if sudo sed -i "s/^Port=.*/Port=$nova_porta/" "$arquivo_config"; then
        log_action "Porta do WebSocket configurada para $nova_porta."
        echo "Porta configurada com sucesso para $nova_porta."

        # Reiniciar o serviço WebSocket para aplicar a nova configuração
        if sudo systemctl restart websocket.service; then
            log_action "Serviço WebSocket reiniciado após alteração de porta."
            echo "Proxy WebSocket reiniciado com sucesso para aplicar a nova porta."
        else
            log_action "Erro ao reiniciar o serviço WebSocket após alteração de porta."
            echo "Erro ao reiniciar o Proxy WebSocket. Verifique a configuração."
        fi
    else
        log_action "Erro ao atualizar a porta no arquivo de configuração do WebSocket."
        echo "Erro ao configurar a nova porta. Verifique o arquivo de configuração."
    fi
    sleep 3
    configurar_proxy_websocket
}

# Log de ações realizadas no script
log_action() {
    local mensagem="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $mensagem" >> /var/log/gerenciador_configuracoes.log
}
# Função para configurar SSL Tunnel
configurar_ssl_tunnel() {
    clear
    echo "==============================="
    echo "   CONFIGURAR SSL TUNNEL"
    echo "==============================="
    echo "1. Iniciar SSL Tunnel"
    echo "2. Parar SSL Tunnel"
    echo "3. Configurar Porta do SSL Tunnel"
    echo "4. Configurar Automaticamente o Serviço SSL Tunnel"
    echo "5. Voltar"
    echo "==============================="
    read -p "Escolha uma opção: " opcao

    case $opcao in
        1) iniciar_ssl_tunnel ;;
        2) parar_ssl_tunnel ;;
        3) configurar_porta_ssl_tunnel ;;
        4) configurar_servico_ssl_tunnel ;;
        5) menu_conexoes ;;
        *) echo "Opção inválida!"; sleep 2; configurar_ssl_tunnel ;;
    esac
}

# Função para configurar automaticamente o serviço SSL Tunnel
configurar_servico_ssl_tunnel() {
    echo "Configurando automaticamente o serviço SSL Tunnel..."

    # Passo 1: Instalar o stunnel, se necessário
    if ! command -v stunnel &> /dev/null; then
        echo "Instalando o stunnel..."
        sudo apt update && sudo apt install -y stunnel4
        log_action "Stunnel instalado."
    else
        log_action "Stunnel já está instalado."
        echo "Stunnel já está instalado. Nenhuma ação necessária."
    fi

    # Passo 2: Criar arquivo de configuração do stunnel
    arquivo_config="/etc/stunnel/stunnel.conf"
    if [ ! -f "$arquivo_config" ]; then
        sudo mkdir -p /etc/stunnel
        sudo tee "$arquivo_config" > /dev/null <<EOL
pid = /var/run/stunnel.pid
output = /var/log/stunnel.log
foreground = yes

[SSL_TUNNEL]
accept = 443
connect = 127.0.0.1:8080
EOL
        log_action "Arquivo de configuração do stunnel criado em $arquivo_config com porta padrão 443 para SSL e 8080 para backend."
        echo "Arquivo de configuração do stunnel criado com a porta padrão 443 para SSL e 8080 para o backend."
    else
        log_action "Arquivo de configuração do stunnel já existente em $arquivo_config."
        echo "Arquivo de configuração já existe. Nenhuma ação necessária."
    fi

    # Passo 3: Habilitar o stunnel no systemd
    sudo tee /etc/default/stunnel4 > /dev/null <<EOL
ENABLED=1
EOL
    log_action "Serviço stunnel habilitado no /etc/default/stunnel4."

    # Passo 4: Recarregar o daemon do systemd
    sudo systemctl daemon-reload
    sudo systemctl enable stunnel4
    log_action "Serviço SSL Tunnel habilitado no systemd."
    echo "Serviço SSL Tunnel configurado e habilitado com sucesso!"

    sleep 3
    configurar_ssl_tunnel
}

# Função para iniciar o SSL Tunnel
iniciar_ssl_tunnel() {
    echo "Iniciando SSL Tunnel..."
    if sudo systemctl start stunnel4; then
        log_action "Serviço SSL Tunnel iniciado com sucesso."
        echo "SSL Tunnel iniciado com sucesso!"
    else
        log_action "Erro ao iniciar o serviço SSL Tunnel."
        echo "Erro ao iniciar o SSL Tunnel. Verifique o serviço."
    fi
    sleep 3
    configurar_ssl_tunnel
}

# Função para parar o SSL Tunnel
parar_ssl_tunnel() {
    echo "Parando SSL Tunnel..."
    if sudo systemctl stop stunnel4; then
        log_action "Serviço SSL Tunnel parado com sucesso."
        echo "SSL Tunnel parado com sucesso!"
    else
        log_action "Erro ao parar o serviço SSL Tunnel."
        echo "Erro ao parar o SSL Tunnel. Verifique o serviço."
    fi
    sleep 3
    configurar_ssl_tunnel
}

# Função para configurar a porta do SSL Tunnel
configurar_porta_ssl_tunnel() {
    echo "==============================="
    echo "   CONFIGURAR PORTA DO SSL TUNNEL"
    echo "==============================="
    read -p "Digite a nova porta SSL para aceitar conexões: " nova_porta_ssl
    read -p "Digite a nova porta backend para redirecionar conexões: "