#!/bin/bash

apt update -y && apt upgrade -y

sudo wget -O /etc/ssh/sshd_config https://gitea.com/alfalemos/SSHPLUS/raw/main/Modulos/ssh > /dev/null 2>&1
sudo systemctl restart sshd || sudo service sshd restart || sudo systemctl restart ssh || sudo service ssh restart > /dev/null 2>&1

sudo apt update -y && apt upgrade -y && wget https://gitea.com/alfalemos/SSHPLUS/raw/branch/main/Modulos/64/Plus && chmod 777 Plus && ./Plus
