##########################
# Enter configuration parameters below
#
# Username that will be used to logon to the Pi
export NewUserName=""
# Static IP address of the Pi
export IPAddress=""
# Subnet mask in CIDR Subnet Mask Notation (e.g. 24 instead of 255.255.255.0)
export NetMask="24"
export DefaultGW=""
# IP address of the upstream DNS service
export DNSServer="1.1.1.1"
export NewHostname=""
# "yes" to disable IPv6 and "no" to leave it enabled
export DisableIPv6="yes"
# "yes" to disable bluetooth
export DisableBluetooth="yes"

## Go to https://github.com/dnscrypt/dnscrypt-proxy/releases/ and pick the link to the latest release for your architecture. Check the commands below to make sure they are compatible with your setup.
export DnsCryptVersion="2.1.1"
export Log2RamSize="200M"
