#!/bin/bash


mkdir /opt
mkdir /opt/hsproxy

arch=$(uname -m)

[ -f /opt/hsproxy/proxy ] && rm -f /opt/hsproxy/proxy
[ -f /opt/hsproxy/sslproxy ] && rm -f /opt/hsproxy/sslproxy
[ -f /opt/hsproxy/menu ] && rm -f /opt/hsproxy/menu


if [[ $arch == "x86_64" || $arch == "amd64" || $arch == "x86_64h" ]]; then
    echo "Sistema baseado em x86_64 (64-bit Intel/AMD)"
    curl -o "/opt/hsproxy/proxy" -f "https://raw.githubusercontent.com/sofrenoob/Gggggg/main/h/proxy"
    curl -o "/opt/hsproxy/sslproxy" -f "https://raw.githubusercontent.com/sofrenoob/Gggggg/main/h/sslproxy"
    curl -o "/opt/hsproxy/menu" -f "https://raw.githubusercontent.com/sofrenoob/Gggggg/main/h/menu_x64"
elif [[ $arch == "aarch64" || $arch == "arm64" || $arch == "armv8-a" ]]; then
    echo "Sistema baseado em arm64 (64-bit ARM)"
    curl -o "/opt/hsproxy/proxy" -f "https://raw.githubusercontent.com/sofrenoob/Gggggg/main/h/proxy"
    curl -o "/opt/hsproxy/sslproxy" -f "https://raw.githubusercontent.com/sofrenoob/Gggggg/main/h/sslproxy"
    curl -o "/opt/hsproxy/menu" -f "https://raw.githubusercontent.com/sofrenoob/Gggggg/main/h/menu_x64"
else
    echo "Arquitetura não reconhecida: $arch"
    return
fi

curl -o "/opt/hsproxy/cert.pem" -f "https://raw.githubusercontent.com/sofrenoob/Gggggg/main/h/cert.pem"
curl -o "/opt/hsproxy/key.pem" -f "https://raw.githubusercontent.com/sofrenoob/Gggggg/main/h/key.pem"

chmod +x /opt/hsproxy/proxy
chmod +x /opt/hsproxy/sslproxy
chmod +x /opt/hsproxy/menu

ln -s /opt/hsproxy/menu /usr/local/bin/hsproxy
clear
echo -e "Para iniciar o menu digite: hsproxy"