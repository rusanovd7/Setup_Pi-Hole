#!/bin/bash
#set -x

source ./Setup_Pi-hole_vars.sh

if [[ $(whoami) != root ]]; then
    echo "The script must be run as root. Exiting"
    exit 1
fi

CurrentDir=$(pwd)

#pushd . || exit 1

apt update && apt upgrade -y && apt autoremove -y
apt install neovim locate rsync bind9-dnsutils -y

if [[ $(apt list --installed 2>/dev/null | grep netcat) == "" ]]; then
    apt install netcat-openbsd -y
fi

if [[ "${DNSCryptPort}" == "" ]]; then
    DNSCryptPort="54"
fi

if [[ "${NewUserName}" != "" ]]; then
    if [[ $(compgen -u | grep "${NewUserName}") == "" ]]; then
        echo "Creating user ${NewUserName}"
        useradd "${NewUserName}" -s /bin/bash -m -G adm,sudo && echo "User ${NewUserName} added"
        sed -i '/#alias ll=/s/^#//' "/home/${NewUserName}/.bashrc"
    else
        echo "User ${NewUserName} already exists."
    fi
fi

CurrentHostname=$(hostname)
if [[ "${NewHostname}" != "" ]] && [[ "${CurrentHostname}" != "${NewHostname}" ]]; then
    hostnamectl set-hostname "${NewHostname}" && sed -i "s/$CurrentHostname/$NewHostname/g" /etc/hosts && echo "New hostname ${NewHostname} set successfully."
fi

## Check & abort if any of the needed ports are already in use.
BLOCKED=()
for port in 53 "${DNSCryptPort}" 80 443; do  # TCP only
    if nc -z -w 1 localhost "${port}" 2>/dev/null; then
        BLOCKED+=("${port}/tcp")
    fi
done

if nslookup -timeout=1 localhost 127.0.0.1 &>/dev/null; then  # UDP 53 separately.
    BLOCKED+=("53/udp")
fi

if [ ${#BLOCKED[@]} -gt 0 ]; then
    echo "ERROR: the followng ports are already in use: ${BLOCKED[*]}. Aborting."
    exit 1
fi

## Raspberry Pi-specific configuration
if [ -f /etc/rpi-issue ] || [[ $(grep -i raspb /etc/os-release) != "" ]] ; then

    if [[ "${MaxRAM}" == "yes" ]]; then
        if [[ $(grep "^gpu_mem=" /boot/firmware/config.txt) == "" ]]; then
            echo "gpu_mem=32" >> /boot/firmware/config.txt && echo "Setting gpu_mem to 32MB"  #Reduce the amount of memory allocated for the iGPU
        else
            echo "gpu_mem already set to a custom value. Skipping."
        fi
    fi

    if [[ "${DisableBluetooth}" == "yes" && $(grep "disable-bt" /boot/firmware/config.txt) == "" ]]; then
        echo "dtoverlay=disable-bt" >> /boot/firmware/config.txt && echo "Bluetooth successfully disabled."
    fi

    if [[ "${DisableIPv6}" == "yes" && $(grep "disable_ipv6" /etc/sysctl.d/*) == "" ]]; then
        tee /etc/sysctl.d/99-disable-ipv6.conf > /dev/null << 'EOF'
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
        sysctl --system && echo "IPv6 successfully disabled."
    fi

    if [[ $(ifconfig | grep -v "127.0.0.1" | grep -B 1 inet\ | grep -v inet | cut -d ':' -f 1 | wc -l) -eq 1 ]] && [[ "${IPAddress}" != "" ]]; then
        # Checks which interface is connected. Does not work if more than one interfaces are connected or if Docker is installed.
        Interface=$(ifconfig | grep -v "127.0.0.1" | grep -B 1 inet\ | grep -v inet | cut -d ':' -f 1)
        Connection_part=$(nmcli connection show | grep "${Interface}" | awk '{print $1}')
        Connection=$(nmcli -g NAME connection | grep "${Connection_part}")

        if [[ $(grep -r "method=manual" /etc/NetworkManager/ | grep -v "#") == "" ]]; then
            echo "Writing new config for ${Interface}"
            nmcli con mod "${Connection}" ipv4.addresses "${IPAddress}"/"${NetMask}"
            nmcli con mod "${Connection}" ipv4.gateway "${DefaultGW}"
            nmcli con mod "${Connection}" ipv4.method manual
            nmcli con mod "${Connection}" ipv4.dns "${DNSServer}" && echo "${Interface} configured with ${IPAddress}/${NetMask}"  # Configure OS to use the locally running Pi-hole as the DNS resolver
        else
            echo "A static IP address appears to have been already set. Please check."
        fi
    else
        echo "More than one interface is connected or docker is installed. Skipping IP configuration"
    fi

    # https://www.raspberrypi.com/documentation/computers/configuration.html#wifi-cc-rfkill
    if [[ "$Interface" == "wlan"* ]]; then
        rfkill unblock wlan
    # Disables WiFi if not in use
    elif [[ "${DisableWiFi}" == "yes" && $(grep "disable-wifi" /boot/firmware/config.txt) == "" ]]; then
        echo "dtoverlay=disable-wifi" >> /boot/firmware/config.txt && echo "Wi-Fi successfully disabled"
    fi
else
    echo "OS does not seem to be Raspberry Pi OS. Skipping Raspberry Pi-specific steps"
fi

## Install and configure dnscrypt-proxy
if [[ $(apt list --installed 2>/dev/null | grep dnscrypt) == "" ]]; then

    apt install dnscrypt-proxy -y
    
    # Override the dnscrypt listen port
    mkdir -p /etc/systemd/system/dnscrypt-proxy.socket.d/
    cat << EOF > /etc/systemd/system/dnscrypt-proxy.socket.d/override.conf
[Socket]
ListenStream=
ListenDatagram=
ListenStream=127.0.0.1:${DNSCryptPort}
ListenDatagram=127.0.0.1:${DNSCryptPort}
EOF
    
    cp /etc/dnscrypt-proxy/dnscrypt-proxy.toml /etc/dnscrypt-proxy/dnscrypt-proxy.bak
    mv /etc/dnscrypt-proxy/dnscrypt-proxy.toml /etc/dnscrypt-proxy/dnscrypt-proxy.temp
    sed -i '/require_dnssec/d' /etc/dnscrypt-proxy/dnscrypt-proxy.temp
    sed -i '/server_names \=/d' /etc/dnscrypt-proxy/dnscrypt-proxy.temp
    sed -i '/fallback_resolver.*\=/d' /etc/dnscrypt-proxy/dnscrypt-proxy.temp

    
    if [[ $(dpkg --print-architecture) == "armhf" ]]; then

    # Changing DNS resolver to 'cloudflare', downgrading to TLS 1.2 ( TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305 [52392] ) if running on a 32-bit Raspberry Pi or other 32-bit ARM CPU. 
    cat << EOF > /etc/dnscrypt-proxy/dnscrypt-proxy.toml
server_names = ['cloudflare']
require_dnssec = true
tls_cipher_suite = [52392] # Change to "tls_prefer_rsa = true" if dnscrypt-proxy version >= 2.1.16 !!
EOF
    else
    cat << EOF > /etc/dnscrypt-proxy/dnscrypt-proxy.toml
server_names = ['${DNSCryptResolver}']
require_dnssec = true
EOF
    fi

    # Don't waste CPU cycles querying IPv6 it is/will be disabled.
    if [[ "${DisableIPv6}" == "yes" || $(grep "disable_ipv6" /etc/sysctl.d/*) != "" ]]; then 
        echo "block_ipv6 = true" >> /etc/dnscrypt-proxy/dnscrypt-proxy.toml
        echo "ipv6_servers = false" >> /etc/dnscrypt-proxy/dnscrypt-proxy.toml
    fi
    
    cat /etc/dnscrypt-proxy/dnscrypt-proxy.temp >> /etc/dnscrypt-proxy/dnscrypt-proxy.toml

    # Reload and restart
    systemctl daemon-reload
    systemctl restart dnscrypt-proxy.socket dnscrypt-proxy.service

else
    echo "dncrypt-proxy seems to already have been installed. Check its configuration manually"
fi

## Install Pi-hole
if [[ $(which pihole) == "" ]] && [[ $(docker ps 2>&1 | grep pihole) == "" ]]; then

    if [[ $(dpkg --print-architecture) == "amd64" || $(dpkg --print-architecture) == "arm64" ]]; then  #Docker no longer supports 32-bit ARM
        # Install Docker and restart the docker service
        if [[ "$(apt list --installed 2>&1 | grep docker-ce)" == "" ]]; then
            curl -sSL https://get.docker.com | sh
            if [[ "${NewUserName}" != "" ]]; then
                usermod -aG docker "${NewUserName}" && echo "${NewUserName} added to the \"docker\" group"
            fi
            sleep 15
            systemctl restart docker
        else
            echo "Docker already installed."
        fi

        mkdir -p /opt/pihole
        cd /opt/pihole || exit 1
        cat << EOF > /opt/pihole/docker-compose.yml
# More info at https://github.com/pi-hole/docker-pi-hole/ and https://docs.pi-hole.net/
services:
  pihole:
    container_name: pihole
    image: pihole/pihole:latest
    environment:
      TZ: '${Timezone}'
      #FTLCONF_dns_listeningMode: 'ALL'
      FTLCONF_dns_upstreams: '127.0.0.1#${DNSCryptPort}'
    volumes:
      - './etc-pihole:/etc/pihole'
      - '/etc/hosts:/etc/hosts:ro'  #allows entries in the hosts file on the Docker to be added as local DNS records in Pi-hole
    cap_add:
      - SYS_NICE
    # Required for the container to communicate with dnscrypt-proxy on the host. Do NOT expose the Pi-hole to the open Internet:
    network_mode: host
    restart: unless-stopped
EOF

        docker compose up -d
        sleep 20
        while read -r domain; do
            docker container exec pihole pihole allow "${domain}"
        done < "${CurrentDir}/AllowList.txt"

    else    #Interactive installation on bare metal required on architectures not supported by Docker
        curl -sSL https://install.pi-hole.net | bash
        
        sleep 15

        while read -r domain; do
            pihole allow "${domain}"
        done < "${CurrentDir}/AllowList.txt"
    fi
    # Add a blocklist update job every Monday morning
    crontab -l > crontmp
    echo "0 6 * * 1 /usr/local/bin/pihole -g > /home/${NewUserName}/pihole_gravity_update.log 2>&1" >> crontmp
    crontab crontmp
    rm crontmp
else
    echo "Pi-hole seems to have already been installed"
fi

if [[ "${InstallLog2ram}" == "yes" ]]; then
    apt install log2ram -y
fi