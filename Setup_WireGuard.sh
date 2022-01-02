#!/bin/bash

source ./Setup_Pi-hole_vars.sh

# Install Docker. Fails to start the docker service
if [[ "$(apt list 2>&1 | grep docker-ce)" == "" ]]; then
    curl -sSL https://get.docker.com | sh
    usermod -aG docker "${NewUserName}"
fi

sleep 10

systemctl restart docker

# Install docker-compose
#if [[ "$(apt list 2>&1 | grep docker-compose)" == "" ]]; then
    apt install docker-compose -y
#fi 

# Create the WireGuard docker-compose.yml file and start the container
mkdir -p /opt/wireguard-server
cd /opt/wireguard-server || exit 1

cat << EOF > /opt/wireguard-server/docker-compose.yml
version: "2.1"
services:
  wireguard:
    image: ghcr.io/linuxserver/wireguard
    container_name: wireguard
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=${Timezone}
      - SERVERURL=${ServerURL}
      - SERVERPORT=${WGPort}
      - PEERS=${Peers}
# Currently Pi-Hole cannot be used as a DNS server for WG clients. WiP
#     - PEERDNS=${IPAddress}
      - PEERDNS=1.1.1.1
      - INTERNAL_SUBNET=10.13.13.0
      - ALLOWEDIPS=0.0.0.0/0
    volumes:
      - ./config:/config
      - /lib/modules:/lib/modules
    ports:
      - ${WGPort}:51820/udp
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
      - net.ipv4.ip_forward=1
    restart: unless-stopped
EOF

docker-compose up -d
