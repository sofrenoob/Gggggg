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
    read -p "Digite a nova porta backend para redirecionar conexões: " nova_porta_backend

    # Caminho do arquivo de configuração do stunnel
    arquivo_config="/etc/stunnel/stunnel.conf"

    # Atualizar as portas no arquivo de configuração
    if sudo sed -i -e "s/^accept = .*/accept = $nova_porta_ssl/" -e "s/^connect = .*/connect = 127.0.0.1:$nova_porta_backend/" "$arquivo_config"; then
        log_action "Portas do SSL Tunnel configuradas para SSL: $nova_porta_ssl, Backend: $nova_porta_backend."
        echo "Portas configuradas com sucesso: SSL ($nova_porta_ssl), Backend ($nova_porta_backend)."

        # Reiniciar o serviço SSL Tunnel para aplicar as alterações
        if sudo systemctl restart stunnel4; then
            log_action "Serviço SSL Tunnel reiniciado após alterar as portas."
            echo "SSL Tunnel reiniciado com sucesso para aplicar as novas portas."
        else
            log_action "Erro ao reiniciar o serviço SSL Tunnel após alterar as portas."
            echo "Erro ao reiniciar o SSL Tunnel. Verifique o arquivo de configuração."
        fi
    else
        log_action "Erro ao atualizar as portas no arquivo de configuração do stunnel."
        echo "Erro ao configurar as novas portas. Verifique o arquivo de configuração."
    fi
    sleep 3
    configurar_ssl_tunnel
}

# Função para registrar ações no log
log_action() {
    local mensagem="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $mensagem" >> /var/log/gerenciador_configuracoes.log
}
# Função para configurar V2Ray
configurar_v2ray() {
    clear
    echo "==============================="
    echo "   CONFIGURAR V2RAY"
    echo "==============================="
    echo "1. Iniciar V2Ray"
    echo "2. Parar V2Ray"
    echo "3. Configurar Porta do V2Ray"
    echo "4. Configurar Automaticamente o Serviço V2Ray"
    echo "5. Voltar"
    echo "==============================="
    read -p "Escolha uma opção: " opcao

    case $opcao in
        1) iniciar_v2ray ;;
        2) parar_v2ray ;;
        3) configurar_porta_v2ray ;;
        4) configurar_servico_v2ray ;;
        5) menu_conexoes ;;
        *) echo "Opção inválida!"; sleep 2; configurar_v2ray ;;
    esac
}

# Função para configurar automaticamente o serviço V2Ray
configurar_servico_v2ray() {
    echo "Configurando automaticamente o serviço V2Ray..."

    # Passo 1: Instalar o V2Ray, se necessário
    if ! command -v v2ray &> /dev/null; then
        echo "Instalando o V2Ray..."
        bash <(curl -L -s https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
        log_action "V2Ray instalado."
    else
        log_action "V2Ray já está instalado."
        echo "V2Ray já está instalado. Nenhuma ação necessária."
    fi

    # Passo 2: Criar o arquivo de configuração do V2Ray
    arquivo_config="/usr/local/etc/v2ray/config.json"
    if [ ! -f "$arquivo_config" ]; then
        sudo mkdir -p /usr/local/etc/v2ray
        sudo tee "$arquivo_config" > /dev/null <<EOL
{
  "inbounds": [
    {
      "port": 1080,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "11111111-1111-1111-1111-111111111111",
            "alterId": 64
          }
        ]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOL
        log_action "Arquivo de configuração do V2Ray criado em $arquivo_config com a porta padrão 1080."
        echo "Arquivo de configuração criado com a porta padrão 1080."
    else
        log_action "Arquivo de configuração do V2Ray já existente em $arquivo_config."
        echo "Arquivo de configuração já existe. Nenhuma ação necessária."
    fi

    # Passo 3: Habilitar e iniciar o serviço V2Ray no systemd
    sudo systemctl daemon-reload
    sudo systemctl enable v2ray.service
    log_action "Serviço V2Ray habilitado no systemd."
    echo "Serviço V2Ray configurado e habilitado com sucesso!"

    sleep 3
    configurar_v2ray
}

# Função para iniciar o V2Ray
iniciar_v2ray() {
    echo "Iniciando V2Ray..."
    if sudo systemctl start v2ray.service; then
        log_action "Serviço V2Ray iniciado com sucesso."
        echo "V2Ray iniciado com sucesso!"
    else
        log_action "Erro ao iniciar o serviço V2Ray."
        echo "Erro ao iniciar o V2Ray. Verifique o serviço."
    fi
    sleep 3
    configurar_v2ray
}

# Função para parar o V2Ray
parar_v2ray() {
    echo "Parando V2Ray..."
    if sudo systemctl stop v2ray.service; then
        log_action "Serviço V2Ray parado com sucesso."
        echo "V2Ray parado com sucesso!"
    else
        log_action "Erro ao parar o serviço V2Ray."
        echo "Erro ao parar o V2Ray. Verifique o serviço."
    fi
    sleep 3
    configurar_v2ray
}

# Função para configurar a porta do V2Ray
configurar_porta_v2ray() {
    echo "==============================="
    echo "   CONFIGURAR PORTA DO V2RAY"
    echo "==============================="
    read -p "Digite a nova porta para o V2Ray: " nova_porta

    # Caminho do arquivo de configuração do V2Ray
    arquivo_config="/usr/local/etc/v2ray/config.json"

    # Atualizar a porta no arquivo de configuração
    if sudo sed -i "s/\"port\": [0-9]*/\"port\": $nova_porta/" "$arquivo_config"; then
        log_action "Porta do V2Ray configurada para $nova_porta."
        echo "Porta configurada com sucesso para $nova_porta."

        # Reiniciar o serviço V2Ray para aplicar a nova configuração
        if sudo systemctl restart v2ray.service; then
            log_action "Serviço V2Ray reiniciado após alteração de porta."
            echo "V2Ray reiniciado com sucesso para aplicar a nova porta."
        else
            log_action "Erro ao reiniciar o serviço V2Ray após alteração de porta."
            echo "Erro ao reiniciar o V2Ray. Verifique o arquivo de configuração."
        fi
    else
        log_action "Erro ao atualizar a porta no arquivo de configuração do V2Ray."
        echo "Erro ao configurar a nova porta. Verifique o arquivo de configuração."
    fi
    sleep 3
    configurar_v2ray
}

# Função para registrar ações no log
log_action() {
    local mensagem="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $mensagem" >> /var/log/gerenciador_configuracoes.log
}
# Função para configurar XRay
configurar_xray() {
    clear
    echo "==============================="
    echo "   CONFIGURAR XRAY"
    echo "==============================="
    echo "1. Iniciar XRay"
    echo "2. Parar XRay"
    echo "3. Configurar Porta do XRay"
    echo "4. Configurar Automaticamente o Serviço XRay"
    echo "5. Voltar"
    echo "==============================="
    read -p "Escolha uma opção: " opcao

    case $opcao in
        1) iniciar_xray ;;
        2) parar_xray ;;
        3) configurar_porta_xray ;;
        4) configurar_servico_xray ;;
        5) menu_conexoes ;;
        *) echo "Opção inválida!"; sleep 2; configurar_xray ;;
    esac
}

# Função para configurar automaticamente o serviço XRay
configurar_servico_xray() {
    echo "Configurando automaticamente o serviço XRay..."

    # Passo 1: Instalar o XRay, se necessário
    if ! command -v xray &> /dev/null; then
        echo "Instalando o XRay..."
        bash <(curl -L -s https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)
        log_action "XRay instalado."
    else
        log_action "XRay já está instalado."
        echo "XRay já está instalado. Nenhuma ação necessária."
    fi

    # Passo 2: Criar o arquivo de configuração do XRay
    arquivo_config="/usr/local/etc/xray/config.json"
    if [ ! -f "$arquivo_config" ]; then
        sudo mkdir -p /usr/local/etc/xray
        sudo tee "$arquivo_config" > /dev/null <<EOL
{
  "inbounds": [
    {
      "port": 10000,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "22222222-2222-2222-2222-222222222222",
            "alterId": 64
          }
        ]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOL
        log_action "Arquivo de configuração do XRay criado em $arquivo_config com a porta padrão 10000."
        echo "Arquivo de configuração criado com a porta padrão 10000."
    else
        log_action "Arquivo de configuração do XRay já existente em $arquivo_config."
        echo "Arquivo de configuração já existe. Nenhuma ação necessária."
    fi

    # Passo 3: Habilitar e iniciar o serviço XRay no systemd
    sudo systemctl daemon-reload
    sudo systemctl enable xray.service
    log_action "Serviço XRay habilitado no systemd."
    echo "Serviço XRay configurado e habilitado com sucesso!"

    sleep 3
    configurar_xray
}

# Função para iniciar o XRay
iniciar_xray() {
    echo "Iniciando XRay..."
    if sudo systemctl start xray.service; then
        log_action "Serviço XRay iniciado com sucesso."
        echo "XRay iniciado com sucesso!"
    else
        log_action "Erro ao iniciar o serviço XRay."
        echo "Erro ao iniciar o XRay. Verifique o serviço."
    fi
    sleep 3
    configurar_xray
}

# Função para parar o XRay
parar_xray() {
    echo "Parando XRay..."
    if sudo systemctl stop xray.service; then
        log_action "Serviço XRay parado com sucesso."
        echo "XRay parado com sucesso!"
    else
        log_action "Erro ao parar o serviço XRay."
        echo "Erro ao parar o XRay. Verifique o serviço."
    fi
    sleep 3
    configurar_xray
}

# Função para configurar a porta do XRay
configurar_porta_xray() {
    echo "==============================="
    echo "   CONFIGURAR PORTA DO XRAY"
    echo "==============================="
    read -p "Digite a nova porta para o XRay: " nova_porta

    # Caminho do arquivo de configuração do XRay
    arquivo_config="/usr/local/etc/xray/config.json"

    # Atualizar a porta no arquivo de configuração
    if sudo sed -i "s/\"port\": [0-9]*/\"port\": $nova_porta/" "$arquivo_config"; then
        log_action "Porta do XRay configurada para $nova_porta."
        echo "Porta configurada com sucesso para $nova_porta."

        # Reiniciar o serviço XRay para aplicar a nova configuração
        if sudo systemctl restart xray.service; then
            log_action "Serviço XRay reiniciado após alteração de porta."
            echo "XRay reiniciado com sucesso para aplicar a nova porta."
        else
            log_action "Erro ao reiniciar o serviço XRay após alteração de porta."
            echo "Erro ao reiniciar o XRay. Verifique o arquivo de configuração."
        fi
    else
        log_action "Erro ao atualizar a porta no arquivo de configuração do XRay."
        echo "Erro ao configurar a nova porta. Verifique o arquivo de configuração."
    fi
    sleep 3
    configurar_xray
}

# Função para registrar ações no log
log_action() {
    local mensagem="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $mensagem" >> /var/log/gerenciador_configuracoes.log
}
# Função para configurar SlowDNS
# Função para configurar SlowDNS
configurar_slowdns() {
    clear
    echo "==============================="
    echo "   CONFIGURAR SLOWDNS"
    echo "==============================="
    echo "1. Iniciar SlowDNS"
    echo "2. Parar SlowDNS"
    echo "3. Configurar Porta do SlowDNS"
    echo "4. Instalar e Configurar Automaticamente o Serviço SlowDNS"
    echo "5. Voltar"
    echo "==============================="
    read -p "Escolha uma opção: " opcao

    case $opcao in
        1) iniciar_slowdns ;;
        2) parar_slowdns ;;
        3) configurar_porta_slowdns ;;
        4) instalar_e_configurar_servico_slowdns ;;
        5) menu_conexoes ;;
        *) echo "Opção inválida!"; sleep 2; configurar_slowdns ;;
    esac
}
# Função para instalar e configurar automaticamente o SlowDNS
instalar_e_configurar_servico_slowdns() {
    echo "Instalando e configurando automaticamente o SlowDNS..."

    # Passo 1: Instalar o SlowDNS
    if [ ! -f "/usr/bin/slowdns" ]; then
        echo "Baixando e instalando o SlowDNS..."
        # Substitua este exemplo por um comando real que instale o SlowDNS
        sudo curl -o /usr/bin/slowdns https://example.com/slowdns-binary
        sudo chmod +x /usr/bin/slowdns
        log_action "SlowDNS instalado em /usr/bin/slowdns."
        echo "SlowDNS instalado com sucesso."
    else
        log_action "SlowDNS já está instalado."
        echo "SlowDNS já está instalado. Nenhuma ação necessária."
    fi

    # Passo 2: Criar o arquivo de configuração do SlowDNS
    arquivo_config="/etc/slowdns/config.conf"
    if [ ! -f "$arquivo_config" ]; then
        sudo mkdir -p /etc/slowdns
        sudo tee "$arquivo_config" > /dev/null <<EOL
PORT=5300
DOMAIN=example.com
EOL
        log_action "Arquivo de configuração do SlowDNS criado em $arquivo_config com a porta padrão 5300 e domínio example.com."
        echo "Arquivo de configuração criado com a porta padrão 5300 e domínio example.com."
    else
        log_action "Arquivo de configuração do SlowDNS já existente em $arquivo_config."
        echo "Arquivo de configuração já existe. Nenhuma ação necessária."
    fi

    # Passo 3: Criar o arquivo de serviço do systemd
    arquivo_servico="/etc/systemd/system/slowdns.service"
    if [ ! -f "$arquivo_servico" ]; then
        sudo tee "$arquivo_servico" > /dev/null <<EOL
[Unit]
Description=SlowDNS Service
After=network.target

[Service]
ExecStart=/usr/bin/slowdns -p \$(grep 'PORT=' /etc/slowdns/config.conf | cut -d= -f2) -d \$(grep 'DOMAIN=' /etc/slowdns/config.conf | cut -d= -f2)
Restart=always
User=nobody
Group=nogroup

[Install]
WantedBy=multi-user.target
EOL
        log_action "Arquivo de serviço do SlowDNS criado em $arquivo_servico."
        echo "Arquivo de serviço criado em $arquivo_servico."
    else
        log_action "Arquivo de serviço do SlowDNS já existente em $arquivo_servico."
        echo "Arquivo de serviço já existe. Nenhuma ação necessária."
    fi

    # Passo 4: Recarregar o daemon do systemd e habilitar o serviço
    sudo systemctl daemon-reload
    sudo systemctl enable slowdns.service
    log_action "Serviço SlowDNS habilitado no systemd."
    echo "Serviço SlowDNS configurado e habilitado com sucesso!"

    sleep 3
    configurar_slowdns
}

# Função para iniciar o SlowDNS
iniciar_slowdns() {
    echo "Iniciando SlowDNS..."
    if sudo systemctl start slowdns.service; then
        log_action "Serviço SlowDNS iniciado com sucesso."
        echo "SlowDNS iniciado com sucesso!"
    else
        log_action "Erro ao iniciar o serviço SlowDNS."
        echo "Erro ao iniciar o SlowDNS. Verifique o serviço."
    fi
    sleep 3
    configurar_slowdns
}

# Função para parar o SlowDNS
parar_slowdns() {
    echo "Parando SlowDNS..."
    if sudo systemctl stop slowdns.service; then
        log_action "Serviço SlowDNS parado com sucesso."
        echo "SlowDNS parado com sucesso!"
    else
        log_action "Erro ao parar o serviço SlowDNS."
        echo "Erro ao parar o SlowDNS. Verifique o serviço."
    fi
    sleep 3
    configurar_slowdns
}

# Função para configurar a porta do SlowDNS
configurar_porta_slowdns() {
    echo "==============================="
    echo "   CONFIGURAR PORTA DO SLOWDNS"
    echo "==============================="
    read -p "Digite a nova porta para o SlowDNS: " nova_porta

    # Caminho do arquivo de configuração do SlowDNS
    arquivo_config="/etc/slowdns/config.conf"

    # Atualizar a porta no arquivo de configuração
    if sudo sed -i "s/^PORT=.*/PORT=$nova_porta/" "$arquivo_config"; then
        log_action "Porta do SlowDNS configurada para $nova_porta."
        echo "Porta configurada com sucesso para $nova_porta."

        # Reiniciar o serviço SlowDNS para aplicar a nova configuração
        if sudo systemctl restart slowdns.service; then
            log_action "Serviço SlowDNS reiniciado após alteração de porta."
            echo "SlowDNS reiniciado com sucesso para aplicar a nova porta."
        else
            log_action "Erro ao reiniciar o serviço SlowDNS após alteração de porta."
            echo "Erro ao reiniciar o SlowDNS. Verifique o arquivo de configuração."
        fi
    else
        log_action "Erro ao atualizar a porta no arquivo de configuração do SlowDNS."
        echo "Erro ao configurar a nova porta. Verifique o arquivo de configuração."
    fi
    sleep 3
    configurar_slowdns
}

# Função para registrar ações no log
log_action() {
    local mensagem="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $mensagem" >> /var/log/gerenciador_configuracoes.log
}

#!/bin/bash

# Nome do arquivo de log
LOG_FILE="/var/log/gerenciador_configuracoes.log"

# Função para configurar BADVPN
configurar_badvpn() {
    clear
    echo "==============================="
    echo "   CONFIGURAR BADVPN"
    echo "==============================="
    echo "1. Iniciar BADVPN"
    echo "2. Parar BADVPN"
    echo "3. Configurar Porta do BADVPN"
    echo "4. Instalar BADVPN (se necessário)"
    echo "5. Voltar"
    echo "==============================="
    read -p "Escolha uma opção: " opcao

    case $opcao in
        1) iniciar_badvpn ;;
        2) parar_badvpn ;;
        3) configurar_porta_badvpn ;;
        4) instalar_badvpn ;;
        5) menu_principal ;;
        *) echo "Opção inválida!"; sleep 2; configurar_badvpn ;;
    esac
}

# Função para iniciar BADVPN
iniciar_badvpn() {
    echo "Iniciando BADVPN..."
    if nohup badvpn-udpgw --listen-addr 127.0.0.1:7300 > /dev/null 2>&1 &; then
        log_action "BADVPN iniciado na porta 7300."
        echo "BADVPN iniciado na porta 7300."
    else
        log_action "Erro ao iniciar BADVPN."
        echo "Erro ao iniciar BADVPN. Verifique se está instalado."
    fi
    sleep 2
    configurar_badvpn
}

# Função para parar BADVPN
parar_badvpn() {
    echo "Parando BADVPN..."
    if pkill -f "badvpn-udpgw"; then
        log_action "BADVPN foi parado."
        echo "BADVPN foi parado."
    else
        log_action "Erro ao parar BADVPN. Nenhum processo encontrado."
        echo "Erro ao parar BADVPN. Nenhum processo encontrado."
    fi
    sleep 2
    configurar_badvpn
}

# Função para configurar a porta do BADVPN
configurar_porta_badvpn() {
    read -p "Digite a nova porta para o BADVPN: " porta
    echo "Reiniciando BADVPN com a nova porta $porta..."
    pkill -f "badvpn-udpgw"
    sleep 1
    if nohup badvpn-udpgw --listen-addr 127.0.0.1:$porta > /dev/null 2>&1 &; then
        log_action "BADVPN reiniciado na porta $porta."
        echo "BADVPN reiniciado na porta $porta."
    else
        log_action "Erro ao reiniciar BADVPN na porta $porta."
        echo "Erro ao reiniciar BADVPN. Verifique se está instalado."
    fi
    sleep 2
    configurar_badvpn
}

# Função para instalar BADVPN
instalar_badvpn() {
    echo "Instalando BADVPN..."
    if command -v badvpn-udpgw >/dev/null 2>&1; then
        log_action "BADVPN já está instalado."
        echo "BADVPN já está instalado."
    else
        sudo apt update
        sudo apt install -y git build-essential cmake
        git clone https://github.com/ambrop72/badvpn.git /tmp/badvpn
        cd /tmp/badvpn || exit
        cmake . -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1
        make
        sudo cp badvpn-udpgw /usr/bin/
        cd || exit
        sudo rm -rf /tmp/badvpn
        log_action "BADVPN instalado com sucesso."
        echo "BADVPN instalado com sucesso."
    fi
    sleep 2
    configurar_badvpn
}

# Função para registrar logs
log_action() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

#!/bin/bash

# Nome do arquivo de log
LOG_FILE="/var/log/gerenciador_configuracoes.log"

# Função para registrar ações no log
log_action() {
    local mensagem="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $mensagem" >> "$LOG_FILE"
}

# Menu principal para Balanceamento de Carga
menu_balanceamento() {
    clear
    echo "==============================="
    echo "   BALANCEAMENTO DE CARGA"
    echo "==============================="
    echo "1. Ativar Balanceamento de Carga"
    echo "2. Desativar Balanceamento de Carga"
    echo "3. Configurar Manualmente"
    echo "4. Exibir Regras Atuais"
    echo "5. Testar Balanceamento"
    echo "6. Opções Avançadas"
    echo "7. Voltar"
    echo "==============================="
    read -p "Digite a opção desejada: " opcao

    case $opcao in
        1) ativar_balanceamento ;;
        2) desativar_balanceamento ;;
        3) configurar_manual ;;
        4) exibir_regras ;;
        5) testar_balanceamento ;;
        6) opcoes_avancadas ;;
        7) menu_principal ;;
        *) echo "Opção inválida!"; sleep 2; menu_balanceamento ;;
    esac
}

# Funções do Submenu "Balanceamento de Carga"
ativar_balanceamento() {
    echo "Ativando balanceamento de carga..."
    sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -m statistic --mode nth --every 2 --packet 0 -j DNAT --to-destination 192.168.1.2:80
    sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination 192.168.1.3:80
    sudo iptables -t nat -A POSTROUTING -j MASQUERADE
    log_action "Balanceamento de carga ativado entre 192.168.1.2:80 e 192.168.1.3:80."
    echo "Balanceamento de carga ativado."
    sleep 3
    menu_balanceamento
}

desativar_balanceamento() {
    echo "Desativando balanceamento de carga..."
    sudo iptables -t nat -F
    log_action "Balanceamento de carga desativado."
    echo "Balanceamento de carga desativado."
    sleep 3
    menu_balanceamento
}

configurar_manual() {
    echo "Configuração manual do balanceamento."
    echo "Exemplo: Adicionar regra para redirecionar conexões."
    read -p "Digite a porta de origem: " porta_origem
    read -p "Digite o IP de destino: " ip_destino
    read -p "Digite a porta de destino: " porta_destino
    sudo iptables -t nat -A PREROUTING -p tcp --dport "$porta_origem" -j DNAT --to-destination "$ip_destino:$porta_destino"
    log_action "Regra manual adicionada: Porta $porta_origem -> $ip_destino:$porta_destino."
    echo "Regra adicionada com sucesso."
    sleep 3
    menu_balanceamento
}

exibir_regras() {
    echo "Exibindo regras atuais de balanceamento:"
    sudo iptables -t nat -L --line-numbers -n -v
    log_action "Regras de balanceamento exibidas."
    sleep 5
    menu_balanceamento
}

testar_balanceamento() {
    echo "Testando balanceamento de carga..."
    curl -I http://localhost
    log_action "Teste de balanceamento realizado."
    echo "Teste concluído. Verifique o log para mais detalhes."
    sleep 5
    menu_balanceamento
}

# Implementação de opções avançadas
opcoes_avancadas() {
    echo "==============================="
    echo "   OPÇÕES AVANÇADAS"
    echo "==============================="
    echo "1. Configurar Pesos para Servidores"
    echo "2. Configurar Failover"
    echo "3. Voltar"
    echo "==============================="
    read -p "Escolha uma opção: " opcao

    case $opcao in
        1) configurar_pesos ;;
        2) configurar_failover ;;
        3) menu_balanceamento ;;
        *) echo "Opção inválida!"; sleep 2; opcoes_avancadas ;;
    esac
}

# Configurar Pesos para Balanceamento
configurar_pesos() {
    echo "==============================="
    echo "   CONFIGURAR PESOS PARA SERVIDORES"
    echo "==============================="
    echo "Nota: Pesos determinam a prioridade de cada servidor no balanceamento."
    read -p "Digite o IP do servidor primário: " ip1
    read -p "Digite o peso do servidor primário (0.0-1.0, ex.: 0.7 para 70%): " peso1
    read -p "Digite o IP do servidor secundário: " ip2
    read -p "Digite o peso do servidor secundário (0.0-1.0, ex.: 0.3 para 30%): " peso2

    echo "Configurando pesos..."
    sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -m statistic --mode random --probability "$peso1" -j DNAT --to-destination "$ip1:80"
    sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination "$ip2:80"

    log_action "Pesos configurados: $ip1 ($peso1), $ip2 ($peso2)."
    echo "Pesos configurados com sucesso."
    sleep 3
    opcoes_avancadas
}

# Configurar Failover
configurar_failover() {
    echo "==============================="
    echo "   CONFIGURAR FAILOVER"
    echo "==============================="
    echo "Configuração de failover: redirecionar conexões para um servidor de backup em caso de falha."
    read -p "Digite o IP do servidor principal: " ip_principal
    read -p "Digite o IP do servidor de backup: " ip_backup

    echo "Configurando failover..."
    sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -m tcp -j DNAT --to-destination "$ip_principal:80"
    sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -m conntrack --ctstate INVALID -j DNAT --to-destination "$ip_backup:80"

    log_action "Failover configurado: Principal ($ip_principal), Backup ($ip_backup)."
    echo "Failover configurado com sucesso."
    sleep 3
    opcoes_avancadas
}

menu_principal() {
    echo "Menu principal - ainda não implementado."
    exit 0
}

# Início do script
menu_balanceamento

#!/bin/bash

# Função para exibir informações do sistema
info_sistema() {
    clear
    echo "==============================="
    echo "   INFORMAÇÕES DO SISTEMA"
    echo "==============================="

    # Data e Hora
    echo "Data e Hora: $(date '+%Y-%m-%d %H:%M:%S')"

    # Usuário Atual
    echo "Usuário Atual: $(whoami)"

    # Sistema Operacional
    os_name=$(cat /etc/os-release | grep PRETTY_NAME | cut -d '"' -f 2)
    echo "Sistema Operacional: $os_name"

    # CPU
    cpu_model=$(lscpu | grep 'Model name' | sed -r 's/Model name:\s+//')
    cpu_cores=$(lscpu | grep '^CPU(s):' | awk '{print $2}')
    echo "CPU: $cpu_model ($cpu_cores núcleos)"

    # Memória Total
    mem_total=$(free -h | grep Mem | awk '{print $2}')
    echo "Memória Total: $mem_total"

    # Memória Usada
    mem_used=$(free -h | grep Mem | awk '{print $3}')
    echo "Memória Usada: $mem_used"

    # Espaço em Disco
    echo "Espaço em Disco:"
    df -h --output=source,size,used,avail | grep '^/' | awk '{printf "  %s (Tamanho: %s, Usado: %s, Disponível: %s)\n", $1, $2, $3, $4}'

    # Tempo de Atividade do Sistema
    uptime_info=$(uptime -p)
    echo "Tempo de Atividade do Sistema: $uptime_info"

    # Rede (IP e Gateway)
    ip_address=$(ip -4 addr show | grep inet | grep -v '127.0.0.1' | awk '{print $2}' | cut -d'/' -f1)
    gateway=$(ip route | grep default | awk '{print $3}')
    echo "Endereço IP: ${ip_address:-Não detectado}"
    echo "Gateway: ${gateway:-Não detectado}"

    echo "==============================="
    echo "Pressione qualquer tecla para voltar ao menu principal..."
    read -n 1
    menu_principal
}

# Função para sair do sistema
sair() {
    echo "Saindo do sistema..."
    sleep 2
    clear
    exit
}

# Início do menu principal
menu_principal
