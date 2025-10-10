#!/bin/bash

# Script para instalar dependências comuns para executáveis Python e Shell Script
# em sistemas Ubuntu/Debian.

echo "Iniciando a instalação de dependências..."

# Atualiza a lista de pacotes
sudo apt update

# Instala ferramentas de compilação e bibliotecas comuns para executáveis Python
# (necessário para muitas bibliotecas Python que dependem de componentes C/C++)
echo "Instalando dependências para executáveis Python..."
sudo apt install -y build-essential zlib1g-dev libssl-dev libffi-dev

# Instala utilitários comuns que podem ser usados em Shell Scripts
echo "Instalando utilitários comuns para Shell Scripts..."
sudo apt install -y curl wget grep awk sed ssh rsync

# Garante que o bash esteja instalado (geralmente já está em Ubuntu/Debian)
echo "Verificando instalação do bash..."
sudo apt install -y bash

echo "
Instalação de dependências concluída."
echo "Você pode agora tentar executar seus binários ofuscados."

