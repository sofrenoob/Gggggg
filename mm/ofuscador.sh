#!/bin/bash

# Diretório de entrada e saída padrão
DOWNLOAD_DIR="/storage/emulated/0/Download"

# Garante que o diretório de download exista
mkdir -p "$DOWNLOAD_DIR"

function obfuscate_python() {
    echo "\n--- Ofuscar Script Python ---"
    read -p "Digite o nome do arquivo Python a ser ofuscado (ex: meu_script.py): " PYTHON_FILE

    INPUT_FILE="$DOWNLOAD_DIR/$PYTHON_FILE"
    
    if [ ! -f "$INPUT_FILE" ]; then
        echo "Erro: Arquivo 
'$INPUT_FILE
' não encontrado."
        return
    fi

    echo "Ofuscando 
'$PYTHON_FILE
' usando PyInstaller..."
    # PyInstaller cria uma pasta 'dist' e coloca o executável lá.
    # Usamos --distpath para especificar o diretório de saída.
    pyinstaller --onefile --distpath "$DOWNLOAD_DIR" "$INPUT_FILE"

    if [ $? -eq 0 ]; then
        echo "\nOfuscação Python concluída com sucesso!"
        echo "Executável salvo em: $DOWNLOAD_DIR/$(basename "$PYTHON_FILE" .py)"
    else
        echo "\nErro durante a ofuscação do script Python."
    fi
}

function obfuscate_shell() {
    echo "\n--- Ofuscar Shell Script ---"
    read -p "Digite o nome do Shell Script a ser ofuscado (ex: meu_script.sh): " SHELL_FILE

    INPUT_FILE="$DOWNLOAD_DIR/$SHELL_FILE"
    OUTPUT_FILE="$DOWNLOAD_DIR/$(basename "$SHELL_FILE" .sh)"

    if [ ! -f "$INPUT_FILE" ]; then
        echo "Erro: Arquivo 
'$INPUT_FILE
' não encontrado."
        return
    fi

    echo "Ofuscando 
'$SHELL_FILE
' usando shc..."
    shc -f "$INPUT_FILE" -o "$OUTPUT_FILE"

    if [ $? -eq 0 ]; then
        echo "\nOfuscação Shell Script concluída com sucesso!"
        echo "Executável salvo em: $OUTPUT_FILE"
    else
        echo "\nErro durante a ofuscação do Shell Script."
    fi
}

function show_menu() {
    clear
    echo "===================================="
    echo "  Menu de Ofuscação de Scripts    "
    echo "===================================="
    echo "1. Ofuscar Script Python"
    echo "2. Ofuscar Shell Script"
    echo "3. Sair"
    echo "===================================="
    echo -n "Escolha uma opção: "
}

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

