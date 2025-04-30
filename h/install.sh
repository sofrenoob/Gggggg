#!/bin/bash


mkdir /opt
mkdir /opt/hsproxy

arch=$(uname -m)

[ -f /opt/hsproxy/proxy ] && rm -f /opt/hsproxy/proxy
[ -f /opt/hsproxy/sslproxy ] && rm -f /opt/hsproxy/sslproxy
[ -f /opt/hsproxy/menu ] && rm -f /opt/hsproxy/menu


if [[ $arch == "x86_64" || $arch == "amd64" || $arch == "x86_64h" ]]; then
    echo "Sistema baseado em x86_64 (64-bit Intel/AMD)"
    curl -o "/opt/hsproxy/proxy" -f "https://www.dropbox.com/scl/fi/9clk7toaue0x3t93h2gqv/proxy?rlkey=g6lqom2fv4etfsaha76s4bm0z&st=b4y4e04k&dl=1"
    curl -o "/opt/hsproxy/sslproxy" -f "https://www.dropbox.com/scl/fi/i59hjl0oa6zfl1p6ht5ct/sslproxy?rlkey=vk9rdkoev7ah5izyomqaa4lvr&st=hqmdt6e7&dl=1"
    curl -o "/opt/hsproxy/menu" -f "https://www.dropbox.com/scl/fi/atxwh4y7gi8h9woogs0na/menu_x64?rlkey=blcxmz0zbfwczkxm0g4k608c7&st=yl99sj6o&dl=1"
elif [[ $arch == "aarch64" || $arch == "arm64" || $arch == "armv8-a" ]]; then
    echo "Sistema baseado em arm64 (64-bit ARM)"
    curl -o "/opt/hsproxy/proxy" -f "https://www.dropbox.com/scl/fi/9clk7toaue0x3t93h2gqv/proxy?rlkey=g6lqom2fv4etfsaha76s4bm0z&st=b4y4e04k&dl=1"
    curl -o "/opt/hsproxy/sslproxy" -f "https://www.dropbox.com/scl/fi/i59hjl0oa6zfl1p6ht5ct/sslproxy?rlkey=vk9rdkoev7ah5izyomqaa4lvr&st=hqmdt6e7&dl=1"
    curl -o "/opt/hsproxy/menu" -f "https://www.dropbox.com/scl/fi/atxwh4y7gi8h9woogs0na/menu_x64?rlkey=blcxmz0zbfwczkxm0g4k608c7&st=yl99sj6o&dl=1"
else
    echo "Arquitetura não reconhecida: $arch"
    return
fi

curl -o "/opt/hsproxy/cert.pem" -f "https://www.dropbox.com/scl/fi/y84ssatyftoff5rabz5bv/cert.pem?rlkey=qvln9dbstatsoov5mcjlk7gy7&st=tozuvl2m&dl=1"
curl -o "/opt/hsproxy/key.pem" -f "https://www.dropbox.com/scl/fi/849xtovat2pja94qsf72w/key.pem?rlkey=5lxj93upeo39uj0vwvne9d24a&st=dfeun1di&dl=1"

chmod +x /opt/hsproxy/proxy
chmod +x /opt/hsproxy/sslproxy
chmod +x /opt/hsproxy/menu

ln -s /opt/hsproxy/menu /usr/local/bin/hsproxy
clear
echo -e "Para iniciar o menu digite: hsproxy"