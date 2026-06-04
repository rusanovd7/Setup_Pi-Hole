#!/bin/bash

##########################
# Enter configuration parameters below
#
# Specify the username used for managing the Pi. 
# You can provide an existing username or define a new one to be created during setup.
export NewUserName=""
# Set this variable if you wish to change the hostname. Leave empty otherwise
export NewHostname=""
# Change to your time zone. Needed by the containers. https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
export Timezone=Europe/Sofia
# Specify the listen port for dnssrypt-proxy or leave empty to use port 54
export DNSCryptPort=""
# Upstream resolvers(s) for dnscrypt-proxy. List of available servers here: https://dnscrypt.info/public-servers
export DNSCryptResolver="cloudflare-security"
# Set to "yes" if you want log2ram to be installed. Creates a mount for /var/log in memory to reduce SD card wear
export InstallLog2ram="yes"
#
#
###############################################################################
# RASPBERRY PI SPECIFIC SETTINGS
# Note: The following variables are only applied if this script is executed 
# on Raspberry Pi hardware.
###############################################################################
#
# If set to "yes", the script will reduce the GPU memory to 32MB, in order to provide the maximum amount of RAM to the OS. 
# Ignored if memory has already been set to a custom level. Set to "no" or leave empty to keep the default VRAM amount.
export MaxRAM="yes"
# "yes" to disable IPv6 and "no" to leave it enabled
export DisableIPv6="yes"
# "yes" to disable bluetooth and/or WiFi
export DisableBluetooth="yes"
export DisableWiFi="no"
# Note: Static network configuration is bypassed if multiple non-loopback interfaces are active (e.g., due to Docker)
# or if manual configurations are detected 
export IPAddress=""
# Subnet mask in CIDR Subnet Mask Notation (e.g. 24 instead of 255.255.255.0)
export NetMask="24"
# WARNING: Setting this to 127.0.0.1 makes the Pi use its own local Pi-hole instance.
# While this works, it can cause connectivity issues or infinite loops if the Pi-hole service fails to start.
export DNSServer="1.1.1.2"
export DefaultGW=""

#
###############################################################################
# WIREGUARD CONTAINER SETUP
# Ignore the variables below if you do not need the WireGuard container (requires 64-bit OS).
# If you want to install the linuxserver.io WireGuard container, run Setup_WireGuard.sh manually after the reboot.
###############################################################################
# Your external IP address/FQDN
export ServerURL=""
# Set the number of peers or list them by name (e.g. "laptop,phone,tablet")
export Peers=""
# Set the WireGuard port
export WGPort=51820
