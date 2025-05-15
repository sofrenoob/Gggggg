

# Atualizar pacotes e instalar Node.js e npm
sudo apt update
sudo apt install -y nodejs npm

# Criar diretório do projeto e navegar para ele
mkdir -p websocket-proxy
cd websocket-proxy

# Baixar o script do GitHub
curl -O https://raw.githubusercontent.com/sofrenoob/Gggggg/main/4/proxy.js

# Criar certificados SSL autoassinados (substitua por certificados válidos em produção)
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes -subj "/CN=localhost"

# Inicializar o projeto Node.js
npm init -y

# Instalar dependências necessárias
npm install ws yargs readline-sync winston

# Tornar o script executável
chmod +x proxy.js

# Executar o script
node proxy.js
