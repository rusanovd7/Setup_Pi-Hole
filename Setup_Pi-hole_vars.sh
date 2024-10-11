#!/bin/bash

##########################
# Enter configuration parameters below
#
# Username that will be used to logon to the Pi. Leave empty if not needed.
export NewUserName=""
# Static IP address of the Pi
export IPAddress=""
# Subnet mask in CIDR Subnet Mask Notation (e.g. 24 instead of 255.255.255.0)
export NetMask=""
export DefaultGW=""
# IP address of the upstream DNS service
export DNSServer=""
export NewHostname=""
# "yes" to disable IPv6 and "no" to leave it enabled
export DisableIPv6="yes"
# "yes" to disable bluetooth and/or WiFi
export DisableBluetooth="yes"
export DisableWiFi="no"
# If set to "yes", the script will reduce the GPU memory to 32MB, in order to provide the maximum amount of RAM to the OS. Ignored if memory already set to a custom level. Set to "no" or leave empty to keep the default VRAM amount.
export MaxRAM="yes"
## Go to https://github.com/jedisct1/dnscrypt-proxy/releases/latest and pick the link to the latest release for your architecture (linux_arm/linux_arm64 is for Raspbery Pi OS 32-bt/64-bit).
export DNSCryptLink="https://github.com/DNSCrypt/dnscrypt-proxy/releases/download/2.1.5/dnscrypt-proxy-linux_arm64-2.1.5.tar.gz"
#
#
######## WireGuard server setup ########
# Ignore the variables below if you do not need the WireGuard container (requires 64-bit OS).
# If you want to install the linuxserver.io WireGuard container, run Setup_WireGuard.sh manually after the reboot.
# Change to your time zone
export Timezone=Europe/Sofia
# Your external IP address/domain
export ServerURL=""
# Set the number of peers or list them by name (e.g. "laptop,phone,tablet")
export Peers=""
# Set the WireGuard port
export WGPort=51820