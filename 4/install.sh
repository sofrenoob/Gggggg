

# Link do seu script no repositório (substitua pelo seu link raw)
REPO_URL="https://raw.githubusercontent.com/sofrenoob/Gggggg/main/4/proxy_system.py"
SCRIPT_NAME="proxy_system.py"

# Atualiza o sistema
echo "Atualizando o sistema..."
sudo apt-get update -y && sudo apt-get upgrade -y

# Instala dependências essenciais de compilação e headers
echo "Instalando dependências essenciais..."
sudo apt-get install -y \
    python3 python3-pip git \
    build-essential \
    libffi-dev \
    python3-dev \
    libssl-dev \
    libffi-dev \
    python3-setuptools \
    python3-wheel

# Atualiza o pip para a última versão
echo "Atualizando pip..."
python3 -m pip install --upgrade pip

# Instala as dependências Python necessárias
echo "Instalando dependências Python..."
pip3 install --upgrade websockets paramiko psutil simple_term_menu

# Verifica se a instalação foi bem-sucedida
if [ $? -ne 0 ]; then
  echo "Erro na instalação das dependências Python. Verifique as mensagens acima."
  exit 1
fi

# Cria um diretório para o seu script
INSTALL_DIR="$HOME/proxy_installer"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Baixa seu script
echo "Baixando seu script..."
wget -O "$SCRIPT_NAME" "$REPO_URL"

# Dá permissão de execução
chmod +x "$SCRIPT_NAME"

# Executa o seu script (menu)
echo "Iniciando o menu..."
python3 "$SCRIPT_NAME"
