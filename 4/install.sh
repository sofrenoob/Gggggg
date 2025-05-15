

# Link do seu repositório (substitua pelo seu link raw)
REPO_URL="https://raw.githubusercontent.com/sofrenoob/Gggggg/main/4/proxy_system.py"

# Nome do arquivo do seu script
SCRIPT_NAME="proxy_system.py"

# Atualiza o sistema
echo "Atualizando o sistema..."
sudo apt-get update -y && sudo apt-get upgrade -y

# Instala Python3 e pip, se ainda não estiverem instalados
echo "Instalando Python3 e pip..."
sudo apt-get install -y python3 python3-pip git

# Instala as dependências Python necessárias
echo "Instalando dependências Python..."
pip3 install websockets paramiko psutil simple_term_menu

# Cria um diretório para o seu script (opcional)
INSTALL_DIR="$HOME/proxy_installer"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Baixa seu script (substitua o link pelo seu link raw)
echo "Baixando seu script..."
wget -O "$SCRIPT_NAME" "$REPO_URL"

# Dá permissão de execução
chmod +x "$SCRIPT_NAME"

# Executa o seu script (que inicia o menu interativo)
echo "Iniciando o menu..."
python3 "$SCRIPT_NAME"

