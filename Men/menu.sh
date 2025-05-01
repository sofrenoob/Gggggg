#!/bin/bash

# Função para exibir o menu
exibir_menu() {
    echo "Escolha uma opção:"
    echo "1) proxy 1"
    echo "2) sslproxy 2"
    echo "3) Opção 3"
    echo "4) Opção 4"
    echo "5) Opção 5"
    echo "6) Opção 6"
    echo "7) Opção 7"
    echo "8) Opção 8"
    echo "9) Opção 9"
    echo "10) Opção 10"
    echo "0) Sair"
}

# Função para garantir permissão de execução
dar_permissao_execucao() {
    if [ -f "$1" ]; then
        chmod +x "$1"
        echo "Permissões de execução atribuídas a $1"
    else
        echo "Arquivo $1 não encontrado!"
    fi
}

# Loop até o usuário escolher a opção para sair
while true; do
    exibir_menu
    read -p "Digite sua opção (1-10 ou 0 para sair): " opcao

    case $opcao in
        1)
            dar_permissao_execucao "./proxy"
            ./proxy
            ;;
        2)
            dar_permissao_execucao "./sslproxy"
            ./sslproxy
            ;;
        3)
            dar_permissao_execucao "./resposta_3.sh"
            ./resposta_3.sh
            ;;
        4)
            dar_permissao_execucao "./resposta_4.sh"
            ./resposta_4.sh
            ;;
        5)
            dar_permissao_execucao "./resposta_5.sh"
            ./resposta_5.sh
            ;;
        6)
            dar_permissao_execucao "./resposta_6.sh"
            ./resposta_6.sh
            ;;
        7)
            dar_permissao_execucao "./resposta_7.sh"
            ./resposta_7.sh
            ;;
        8)
            dar_permissao_execucao "./resposta_8.sh"
            ./resposta_8.sh
            ;;
        9)
            dar_permissao_execucao "./resposta_9.sh"
            ./resposta_9.sh
            ;;
        10)
            dar_permissao_execucao "./resposta_10.sh"
            ./resposta_10.sh
            ;;
        0)
            echo "Saindo..."
            break
            ;;
        *)
            echo "Opção inválida. Tente novamente."
            ;;
    esac
done
