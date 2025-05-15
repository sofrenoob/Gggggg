

# Link do seu script no repositório (substitua pelo seu link raw)
REPO_URL="https://raw.githubusercontent.com/sofrenoob/Gggggg/main/4/proxy_system.py"

# Nome do arquivo do seu script
SCRIPT_NAME="proxy_system.py"

# Atualiza o sistema
echo "Atualizando o sistema..."
sudo apt-get update -y && sudo apt-get upgrade -y

# Instala Python3, pip, git e dependências de compilação necessárias
echo "Instalando Python3, pip, git e dependências de compilação..."
sudo apt-get install -y python3 python3-pip git build-essential libffi-dev python3-dev

# Atualiza o pip para a última versão
echo "Atualizando pip..."
python3 -m pip install --upgrade pip

# Instala as dependências Python necessárias
echo "Instalando dependências Python..."
pip3 install websockets paramiko psutil simple_term_menu

# Verifica se a instalação foi bem-sucedida
if [ $? -ne 0 ]; then
  echo "Erro ao instalar dependências Python. Verifique a saída acima."
  exit 1
fi

# Cria um diretório para o seu script (opcional)
INSTALL_DIR="$HOME/proxy_installer"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Baixa seu script
echo "Baixando seu script..."
wget -O "$SCRIPT_NAME" "$REPO_URL"

# Dá permissão de execução ao script
chmod +x "$SCRIPT_NAME"

# Executa o seu script (que inicia o menu interativo)
echo "Iniciando o menu..."
python3 "$SCRIPT_NAME"
