#!/bin/bash

# Script para ofuscar (compilar para binário) scripts Python e Shell Script
# Adaptado para ser executado em um servidor Ubuntu/Debian.
# Os arquivos ofuscados serão salvos na mesma pasta do arquivo de entrada.

# Função para ofuscar scripts Python usando PyInstaller
function obfuscate_python() {
    echo "\n--- Ofuscar Script Python ---"
    read -p "Digite o caminho completo do arquivo Python a ser ofuscado (ex: /root/Download/meu_script.py): " PYTHON_FILE_PATH

    # Verifica se o arquivo existe
    if [ ! -f "$PYTHON_FILE_PATH" ]; then
        echo "Erro: Arquivo '$PYTHON_FILE_PATH' não encontrado."
        return
    fi

    # Extrai o diretório e o nome do arquivo
    INPUT_DIR=$(dirname "$PYTHON_FILE_PATH")
    FILE_NAME=$(basename "$PYTHON_FILE_PATH")
    BASE_NAME=$(basename "$FILE_NAME" .py)

    echo "Ofuscando '$FILE_NAME' usando PyInstaller..."
    
    # PyInstaller cria uma pasta 'dist' e coloca o executável lá.
    # Usamos --distpath para especificar o diretório de saída.
    # O executável final terá o nome do script original (sem .py)
    pyinstaller --onefile --distpath "$INPUT_DIR" "$PYTHON_FILE_PATH"

    if [ $? -eq 0 ]; then
        echo "\nOfuscação Python concluída com sucesso!"
        echo "Executável salvo em: $INPUT_DIR/$BASE_NAME"
    else
        echo "\nErro durante a ofuscação do script Python."
    fi
}

# Função para ofuscar Shell Scripts usando shc
function obfuscate_shell() {
    echo "\n--- Ofuscar Shell Script ---"
    read -p "Digite o caminho completo do Shell Script a ser ofuscado (ex: /root/Download/meu_script.sh): " SHELL_FILE_PATH

    # Verifica se o arquivo existe
    if [ ! -f "$SHELL_FILE_PATH" ]; then
        echo "Erro: Arquivo '$SHELL_FILE_PATH' não encontrado."
        return
    fi

    # Extrai o diretório e o nome do arquivo
    INPUT_DIR=$(dirname "$SHELL_FILE_PATH")
    FILE_NAME=$(basename "$SHELL_FILE_PATH")
    BASE_NAME=$(basename "$FILE_NAME" .sh)

    echo "Ofuscando '$FILE_NAME' usando shc..."
    # shc compila o script e salva o binário no diretório especificado com -o
    shc -f "$SHELL_FILE_PATH" -o "$INPUT_DIR/$BASE_NAME"

    if [ $? -eq 0 ]; then
        echo "\nOfuscação Shell Script concluída com sucesso!"
        echo "Executável salvo em: $INPUT_DIR/$BASE_NAME"
    else
        echo "\nErro durante a ofuscação do Shell Script."
    fi
}

# Função para exibir o menu principal
function show_menu() {
    clear
    echo "===================================="
    echo "  Menu de Ofuscação de Scripts    "
    echo "      (para Servidor Ubuntu)      "
    echo "===================================="
    echo "1. Ofuscar Script Python"
    echo "2. Ofuscar Shell Script"
    echo "3. Sair"
    echo "===================================="
    echo -n "Escolha uma opção: "
}

# Loop principal do menu
while true;
do
    show_menu
    read -r option

    case $option in
        1)
            obfuscate_python
            read -p "Pressione Enter para continuar..."
            ;;
        2)
            obfuscate_shell
            read -p "Pressione Enter para continuar..."
            ;;
        3)
            echo "Saindo..."
            exit 0
            ;;
        *)
            echo "Opção inválida. Tente novamente."
            read -p "Pressione Enter para continuar..."
            ;;
    esac
done

