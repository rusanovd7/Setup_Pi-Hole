#!/bin/bash

source ./Setup_Pi-hole_vars.sh

# Install Docker. Fails to start the docker service
if [[ "$(apt list --installed 2>&1 | grep docker-ce)" == "" ]]; then
    curl -sSL https://get.docker.com | sh
    usermod -aG docker "${NewUserName}" && echo "${NewUserName} added to the \"docker\" group"
    sleep 15
    systemctl restart docker %
else
    echo "Docker already installed."
fi


# Install docker-compose
if [[ "$(apt list --installed 2>&1 | grep docker-compose)" == "" ]]; then
    apt install docker-compose -y
else
    echo "docker-compose already installed"
fi 

# Create the WireGuard docker-compose.yml file and start the container
mkdir -p /opt/wireguard-server
cd /opt/wireguard-server || exit 1

cat << EOF > /opt/wireguard-server/docker-compose.yml
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
      - PEERDNS=${DNSServer}
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

#Allow WG to use Pi-Hole as a DNS server if installed:
if [[ $(which pihole) != "" ]]; then
    sed -i "/PEERDNS=/c \      - PEERDNS=${IPAddress}" /opt/wireguard-server/docker-compose.yml
fi

modprobe wireguard

docker compose up -d