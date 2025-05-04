#!/bin/bash

termux-setup-storage
mkdir -p $HOME/alfa_tools/tmp
curl -L -o $HOME/alfa_tools/alfa_proxy_hunter.sh "https://raw.githubusercontent.com/sofrenoob/Gggggg/main/h/alfa_proxy_hunter.sh"
chmod +x $HOME/alfa_tools/alfa_proxy_hunter.sh
bash $HOME/alfa_tools/alfa_proxy_hunter.sh
