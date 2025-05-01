strings bash <(wget -qO- https://raw.githubusercontent.com/SSHorizon-ofc/manager/main/aarch64/manager)
objdump -d bash <(wget -qO- https://raw.githubusercontent.com/SSHorizon-ofc/manager/main/aarch64/manager)
readelf -a bash <(wget -qO- https://raw.githubusercontent.com/SSHorizon-ofc/manager/main/aarch64/manager)