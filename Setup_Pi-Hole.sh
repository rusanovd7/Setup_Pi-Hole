#!/bin/bash
#set -x

source ./Setup_Pi-hole_vars.sh

apt update && apt upgrade -y && apt autoremove -y
apt install neovim locate rsync

if [[ $(compgen -u | grep ${NewUserName}) == "" ]]; then
    echo "Creating user ${NewUserName}"
    useradd ${NewUserName} -s /bin/bash -m -G adm,sudo && echo "User ${NewUserName} added"
    sed -i '/#alias ll=/s/^#//' "/home/${NewUserName}/.bashrc"
else
    echo "User ${NewUserName} already exists."
fi

if [[ $(grep "gpu_mem" /boot/config.txt ) == "" ]]; then
    echo "gpu_mem=16" >> /boot/config.txt    #Minimize the amount of memory allocated for the GPU
    echo "Setting gpu_mem to 16MB"
else
    echo "gpu_mem already set to a custom value. Skipping."
fi

if [[ "$DisableBluetooth" == "yes" && $(grep "disable-bt" /boot/config.txt) == "" ]]; then
  echo "dtoverlay=disable-bt" >> /boot/config.txt
fi

if [[ "${DisableIPv6}" == "yes" && $(grep "net.ipv6.conf.all.disable_ipv6" /etc/sysctl.conf) == "" ]]; then
    echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
    sysctl -p
fi

Interface=$(ip a | grep -v 127.0.0.1 | grep inet | awk '{ print $NF }')

if [[ $(grep "static ip_address" /etc/dhcpcd.conf | grep -v "#") == "" ]]; then
    echo "Writing new config for ${Interface}"
    cat << _static_ip >> /etc/dhcpcd.conf
interface ${Interface}
static ip_address=${IPAddress}/${NetMask}
static routers=${DefaultGW}
static domain_name_servers=${DNSServer}
_static_ip
    echo "${Interface} configured with ${IPAddress}/${NetMask}"
else
    echo "A static IP address appears to have been already set. Please check."
fi

# https://www.raspberrypi.com/documentation/computers/configuration.html#wifi-cc-rfkill
if [[ "$Interface" == "wlan"* ]]; then
    rfkill unblock wlan
fi

CurrentHostname=$(hostname)
if [ "${CurrentHostname}" != "${NewHostname}" ]; then
    hostnamectl set-hostname "${NewHostname}" && sed -i "s/$CurrentHostname/$NewHostname/g" /etc/hosts && echo "New hostname set successfully."
fi

#Install Pi-hole
if [[ $(which pihole) == "" ]]; then
    #Generate setupVars.conf for Pi-hole with a default password for the admin intefrace "pihole"
    if [ ! -d /etc/pihole ]; then
        mkdir /etc/pihole
    fi
    chown -R pihole:pihole /etc/pihole

    cat << EOF >> /etc/pihole/setupVars.conf
DNSMASQ_LISTENING=single
DNS_FQDN_REQUIRED=true
DNS_BOGUS_PRIV=true
DNSSEC=false
CONDITIONAL_FORWARDING=false
BLOCKING_ENABLED=true
PIHOLE_INTERFACE="${Interface}"
IPV4_ADDRESS="${IPAddress}"/"${NetMask}"
IPV6_ADDRESS=
PIHOLE_DNS_1="${DNSServer}"
QUERY_LOGGING=true
INSTALL_WEB_SERVER=true
INSTALL_WEB_INTERFACE=true
LIGHTTPD_ENABLED=true
ADMIN_EMAIL=
WEBUIBOXEDLAYOUT=boxed
WEBTHEME=default-dark
WEBPASSWORD=5536c470d038c11793b535e8c1176817c001d6f20a4704fa7908939be82e2922
EOF
    wget -O basic-install.sh https://install.pi-hole.net
    bash basic-install.sh --unattended
else
    echo "Pi-Hole seems to already have been installed"
fi

## Go to https://github.com/dnscrypt/dnscrypt-proxy/releases/ and pick the link to the latest release for your architecture. Check the commands below to make sure they are compatible with your setup.
if [[ $(systemctl status dnscrypt-proxy | grep -i "active (running)") == "" ]]; then
    cd /opt || exit 1
    wget https://github.com/DNSCrypt/dnscrypt-proxy/releases/download/2.0.44/dnscrypt-proxy-linux_arm-2.0.44.tar.gz
    tar -xvzf ./dnscrypt-proxy-linux_*.tar.gz
    rm dnscrypt-proxy-linux_*.tar.gz
    mv /opt/linux-arm /opt/dnscrypt-proxy || exit 1
    cd /opt/dnscrypt-proxy || exit 1
    cp /opt/dnscrypt-proxy/example-dnscrypt-proxy.toml /opt/dnscrypt-proxy/dnscrypt-proxy.temp
    sed -i '/listen_addresses \=/d' /opt/dnscrypt-proxy/dnscrypt-proxy.temp
    sed -i '/require_dnssec/d' /opt/dnscrypt-proxy/dnscrypt-proxy.temp
    sed -i '/server_names \=/d' /opt/dnscrypt-proxy/dnscrypt-proxy.temp
    sed -i '/fallback_resolver.*\=/d' /opt/dnscrypt-proxy/dnscrypt-proxy.temp

    cat << EOF > /opt/dnscrypt-proxy/dnscrypt-proxy.toml
listen_addresses = ['127.0.0.1:54']
server_names = ['cloudflare']
require_dnssec = true
fallback_resolvers = ['9.9.9.9:53']
EOF

    cat /opt/dnscrypt-proxy/dnscrypt-proxy.temp >> /opt/dnscrypt-proxy/dnscrypt-proxy.toml

    /opt/dnscrypt-proxy/dnscrypt-proxy -service install
    /opt/dnscrypt-proxy/dnscrypt-proxy -service start

else
    echo "dncrypt-proxy seems to already have been installed"
fi

#Configure Pi-Hole to use dnscryp-proxy
sed -i '/PIHOLE_DNS/d' /etc/pihole/setupVars.conf
echo "PIHOLE_DNS_1=127.0.0.1#54" >> /etc/pihole/setupVars.conf

if [[ $(grep "REV_SERVER=" /etc/pihole/setupVars.conf) == "" ]]; then
    echo "REV_SERVER=false" >> /etc/pihole/setupVars.conf
else
    sed -i '/REV_SERVER=/c \REV_SERVER=false' /etc/pihole/setupVars.conf
fi

[[ -f /etc/dnsmasq.d/02-dnscrypt.conf ]] && sed -i "/proxy-dnssec/d" /etc/dnsmasq.d/02-dnscrypt.conf
echo "proxy-dnssec" >> /etc/dnsmasq.d/02-dnscrypt.conf

sed -i "/server=/c \server=127.0.0.1#54" /etc/dnsmasq.d/01-pihole.conf
pihole restartdns

DebianRelease=$(grep VERSION_CODENAME /etc/os-release | cut -d'=' -f2)
## Install log2ram and configure it to use rsync
echo "deb http://packages.azlux.fr/debian/ $DebianRelease main" | sudo tee /etc/apt/sources.list.d/azlux.list
wget -qO - https://azlux.fr/repo.gpg.key | sudo apt-key add -
apt update
apt install log2ram

sed -i '/USE_RSYNC=/s/false/true/g' /etc/log2ram.conf
