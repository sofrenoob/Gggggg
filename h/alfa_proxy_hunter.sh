#!/bin/bash

# Alfa Proxy Hunter 🚀 by @alfalemos
# Termux friendly

clear
echo -e "\e[1;32m==== Alfa Proxy Hunter 🚀 ====\e[0m"

# Defina o range de IPs
inicio_ip=100.10.10.10
fim_ip=100.10.10.20
portas=(80 8080 443)
saida="$HOME/storage/downloads/proxies_validos.txt"

# Cria arquivo de saída
mkdir -p "$(dirname "$saida")"
echo "" > "$saida"

# Função para testar proxy
testar_proxy() {
  ip=$1
  porta=$2
  resposta=$(timeout 3 curl -s -o /dev/null -w "%{http_code}" http://$ip:$porta)

  if [[ "$resposta" == "200" ]]; then
    echo -e "[+] Testando $ip:$porta... ✅ \e[32mCódigo 200 OK\e[0m"
    echo "$ip:$porta" >> "$saida"
  elif [[ "$resposta" == "101" ]]; then
    echo -e "[+] Testando $ip:$porta... ✅ \e[36mCódigo 101 Switching\e[0m"
    echo "$ip:$porta" >> "$saida"
  else
    echo -e "[+] Testando $ip:$porta... ❌ \e[31mCódigo $resposta\e[0m"
  fi
}

# Converte IP para inteiro
ip_para_int() {
  local IFS=.
  read -r i1 i2 i3 i4 <<< "$1"
  echo $(( (i1<<24) + (i2<<16) + (i3<<8) + i4 ))
}

# Converte inteiro para IP
int_para_ip() {
  echo "$(( ($1>>24)&255 )).$(( ($1>>16)&255 )).$(( ($1>>8)&255 )).$(( $1&255 ))"
}

# Executa varredura
echo -e "\e[1;34mIniciando varredura de $inicio_ip até $fim_ip\e[0m"

start=$(ip_para_int $inicio_ip)
end=$(ip_para_int $fim_ip)

for (( ip=$start; ip<=$end; ip++ )); do
  atual=$(int_para_ip $ip)
  for porta in "${portas[@]}"; do
    testar_proxy $atual $porta &
  done
done

wait

echo -e "\n\e[1;32mVarredura finalizada! Proxies válidos salvos em:\e[0m $saida"
