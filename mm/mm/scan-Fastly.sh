#!/bin/bash

# Display hacker-style interface
clear
echo -e "\033[1;31m
██████╗ ██████╗ ███╗   ██╗ ██████╗ ███╗   ███╗███████╗██╗   ██╗
██╔══██╗██╔══██╗████╗  ██║██╔════╝ ████╗ ████║██╔════╝╚██╗ ██╔╝
██║  ██║██████╔╝██╔██╗ ██║██║  ███╗██╔████╔██║█████╗   ╚████╔╝ 
██║  ██║██╔═══╝ ██║╚██╗██║██║   ██║██║╚██╔╝██║██╔══╝    ╚██╔╝  
██████╔╝██║     ██║ ╚████║╚██████╔╝██║ ╚═╝ ██║███████╗   ██║   
╚═════╝ ╚═╝     ╚═╝  ╚═══╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝   ╚═╝   
------------------------------------------------------
       ANONYMOUS YEMEN | Cloudflare IP Checker
------------------------------------------------------
Developer: \033[1;32mMrPYTHON👿\033[1;31m
@Mr_PYT_HON
------------------------------------------------------
\033[0m"

# Cloudflare CIDR Ranges
RANGES=(
  "104.244.43.0/24"
  "23.235.32.0/20"
  "43.249.72.0/22"
  "103.244.50.0/24"
  "103.245.222.0/23"
  "103.245.224.0/24"
  "104.156.80.0/20"
  "140.248.64.0/18"
  "140.248.128.0/17"
  "146.75.0.0/17"
  "151.101.0.0/16"
  "157.52.64.0/18"
  "167.82.0.0/17"
  "167.82.128.0/20"
  "167.82.160.0/20"
  "167.82.224.0/20"
  "172.111.64.0/18"
  "185.31.16.0/22"
  "199.27.72.0/21"
  "199.232.0.0/16"
)

# Output file for working IPs
OUTPUT_FILE="cdn_Free.txt"
> "$OUTPUT_FILE"

# Function to expand CIDR range
expand_cidr() {
  local range=$1
  IFS=/ read ip mask <<< "$range"
  IFS=. read -r i1 i2 i3 i4 <<< "$ip"
  local ip_start=$(( (i1 << 24) + (i2 << 16) + (i3 << 8) + i4 ))
  local ip_end=$(( ip_start + (1 << (32 - mask)) - 1 ))

  for ((ip=ip_start; ip<=ip_end; ip++)); do
    printf "%d.%d.%d.%d\n" \
      $(( (ip >> 24) & 255 )) \
      $(( (ip >> 16) & 255 )) \
      $(( (ip >> 8) & 255 )) \
      $(( ip & 255 ))
  done
}

# Temporary script to check IPs
check_ip() {
  local IP=$1
  if ping -c 1 -W 1 "$IP" > /dev/null 2>&1; then
    echo "$IP" >> "$OUTPUT_FILE"
    echo -e "\033[1;32m[✔] $IP \033[1;31m| \033[1;32mONLINE \033[1;31m---> Saved to cdn_Free.txt\033[0m"
  else
    echo -e "\033[1;31m[✘] $IP \033[1;31m| OFFLINE\033[0m"
  fi
}

export -f check_ip
export OUTPUT_FILE

# Process each range
for range in "${RANGES[@]}"; do
  echo -e "\033[1;33mScanning Range: $range\033[0m"
  expand_cidr "$range" | xargs -P 20 -n 1 bash -c 'check_ip "$@"' _
done

# Footer
echo -e "\033[1;34m
------------------------------------------------------
Scanning completed successfully! 
Working IPs saved to: $OUTPUT_FILE
ANONYMOUS YEMEN | Developer: MrPYTHON👿
@Mr_PYT_HON
------------------------------------------------------
\033[0m"