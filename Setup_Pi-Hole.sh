#!/bin/bash
#set -x

source ./Setup_Pi-hole_vars.sh

#pushd . || exit 1

apt update && apt upgrade -y && apt autoremove -y
apt install neovim locate rsync -y

if [[ "${NewUserName}" != "" ]]; then
    if [[ $(compgen -u | grep "${NewUserName}") == "" ]]; then
        echo "Creating user ${NewUserName}"
        useradd "${NewUserName}" -s /bin/bash -m -G adm,sudo && echo "User ${NewUserName} added"
        sed -i '/#alias ll=/s/^#//' "/home/${NewUserName}/.bashrc"
    else
        echo "User ${NewUserName} already exists."
    fi
fi

if [[ "${MaxRAM}" == "yes" ]]; then
    if [[ $(grep "^gpu_mem=" /boot/firmware/config.txt) == "" ]]; then
        echo "gpu_mem=32" >> /boot/firmware/config.txt    #Reduce the amount of memory allocated for the GPU
        echo "Setting gpu_mem to 32MB"
    else
        echo "gpu_mem already set to a custom value. Skipping."
    fi
fi

if [[ "$DisableBluetooth" == "yes" && $(grep "disable-bt" /boot/firmware/config.txt) == "" ]]; then
    echo "dtoverlay=disable-bt" >> /boot/firmware/config.txt && echo "Bluetooth successfully disabled."
fi

if [[ "${DisableIPv6}" == "yes" && $(grep "net.ipv6.conf.all.disable_ipv6" /etc/sysctl.conf) == "" ]]; then
    echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf && echo "IPv6 successfully disabled."
    sysctl -p
fi

# Checks which interface is connected. Does not work if more than one interfaces are connected or if Docker is installed.
Interface=$(ifconfig | grep -v "127.0.0.1" | grep -B 1 inet\ | grep -v inet | cut -d ':' -f 1)
Connection_part=$(nmcli connection show | grep "${Interface}" | awk '{print $1}')
Connection=$(nmcli -g NAME connection | grep "${Connection_part}")

if [[ $(grep -r "method=manual" /etc/NetworkManager/ | grep -v "#") == "" ]]; then
    echo "Writing new config for ${Interface}"
    nmcli con mod "${Connection}" ipv4.addresses "${IPAddress}"/"${NetMask}"
    nmcli con mod "${Connection}" ipv4.gateway "${DefaultGW}"
    nmcli con mod "${Connection}" ipv4.method manual
    nmcli con mod "${Connection}" ipv4.dns "${DNSServer}" && echo "${Interface} configured with ${IPAddress}/${NetMask}"
else
    echo "A static IP address appears to have been already set. Please check."
fi

# https://www.raspberrypi.com/documentation/computers/configuration.html#wifi-cc-rfkill
if [[ "$Interface" == "wlan"* ]]; then
    rfkill unblock wlan
# Disables WiFi if not in use
elif [[ "${DisableWiFi}" == "yes" && $(grep "disable-wifi" /boot/firmware/config.txt) == "" ]]; then
    echo "dtoverlay=disable-wifi" >> /boot/firmware/config.txt && echo "Wi-Fi successfully disabled"
fi

CurrentHostname=$(hostname)
if [[ "${NewHostname}" != "" ]] && [[ "${CurrentHostname}" != "${NewHostname}" ]]; then
    hostnamectl set-hostname "${NewHostname}" && sed -i "s/$CurrentHostname/$NewHostname/g" /etc/hosts && echo "New hostname ${NewHostname} set successfully."
fi

#Install Pi-hole
if [[ $(which pihole) == "" ]]; then
    #Generate setupVars.conf for Pi-hole with a default password for the admin intefrace "pihole"
    if [ ! -d /etc/pihole ]; then
        mkdir -p /etc/pihole
    fi
    
    cat << EOF >> /etc/pihole/setupVars.conf
ADMIN_EMAIL=
BLOCKING_ENABLED=true
CACHE_SIZE=10000
CONDITIONAL_FORWARDING=false
DNS_BOGUS_PRIV=true
DNS_FQDN_REQUIRED=true
DNSMASQ_LISTENING=local
DNSSEC=false
INSTALL_WEB_INTERFACE=true
INSTALL_WEB_SERVER=true
IPV4_ADDRESS="${IPAddress}"/"${NetMask}"
IPV6_ADDRESS=
LIGHTTPD_ENABLED=true
PIHOLE_DNS_1="${DNSServer}"
PIHOLE_DNS_2=
PIHOLE_INTERFACE="${Interface}"
QUERY_LOGGING=true
REV_SERVER=false
TEMPERATUREUNIT=C
WEBPASSWORD=5536c470d038c11793b535e8c1176817c001d6f20a4704fa7908939be82e2922
WEBTHEME=default-auto
WEBUIBOXEDLAYOUT=boxed
EOF
    wget -O basic-install.sh https://install.pi-hole.net
    bash basic-install.sh --unattended
else
    echo "Pi-Hole seems to already have been installed"
fi


if [[ $(systemctl status dnscrypt-proxy | grep -i "active (running)") == "" ]]; then
    cd /opt || exit 1
    if [[ "${DNSCryptLink}" == "" ]]; then
        DNSCryptLink="https://github.com/DNSCrypt/dnscrypt-proxy/releases/download/2.1.5/dnscrypt-proxy-linux_arm-2.1.5.tar.gz"
    fi
    wget "${DNSCryptLink}"
    tar -xvzf ./dnscrypt-proxy-linux_*.tar.gz
    rm dnscrypt-proxy-linux_*.tar.gz
    mv /opt/linux-arm* /opt/dnscrypt-proxy || exit 1
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

# Use "rsync" rather than "cp". No longer necessary
#sed -i '/USE_RSYNC=/s/false/true/g' /etc/log2ram.conf

# Increase the size of /var/log to 100 MB. No longer necessary
#sed -i '/^SIZE=/s/40/100/g' /etc/log2ram.conf

# Add a blocklist update job every Monday morning
crontab -l > crontmp
echo "0 6 * * 1 /usr/local/bin/pihole -g > /home/${NewUserName}/pihole_gravity_update.log 2>&1" >> crontmp
crontab crontmp
rm crontmp
