# Setup_Pi-Hole
## Shell scripts for setting up Pi-Hole with dnscrypt, log2ram and an optional WireGuard container on Raspberry Pi OS (Bookworm)

The purpose of the script `Setup_Pi-Hole.sh` is to automate the initial configuration of 32-bit or 64-bit Raspberry Pi OS (Bookworm only!) and the subesequent instalation of Pi-Hole, dnscrypt-proxy and log2ram with suffictient configuration to run using Cloudflare DoH as the upstream resolver. <br />
The script `Setup_WireGuard.sh` installs Docker and spins up a WireGuard container using the linuxserver.io image (64-bit Raspberry OS only!). <br />
This scripts are intended to be run on a fresh installation of Raspberry Pi OS. Some checks exist, in order to prevent the script from breaking an already configured Pi, but none of them can be considered bulletproof, so running on a Pi with some existing configuration is at your own risk. <br />

Follow these steps to install and configure Pi-Hole on your Raspberry Pi: 

1. Use the Raspberry Pi Imager  to install the Raspberry Pi OS Lite (minimal) image to the MicroSD card. The Raspberry Pi Imager allows some initial configuration such as username, Wi-Fi network, SSH, etc.
2. Insert the SD card into the Pi and connect power (and Ethernet if not using WiFi)
3. SSH into the Pi with the account created by the Raspberry Pi Imager
4. Copy the scripts `Setup_Pi-Hole.sh` and `Setup_Pi-hole_vars.sh` to a temporary directory on the Raspberry Pi and make them executable
5. If you would like to install WireGuard, copy `Setup_WireGuard.sh` too (64-bit OS only)
6. Open the script `Setup_Pi-hole_vars.sh` with a text editor and fill/edit the values according to your requirements
7. Execute the script `Setup_Pi-Hole.sh` as `root` (or with sudo)
8. Reboot
9. Login and become `root`. Use the new IP address when connecting
10. If the script was used for creating a new user, configure a password for it
11. After the installation the password for the Pi-Hole Web UI is "pihole". Execute `pihole -a -p` in order to set a new password
12. Configure the Raspberry Pi as the DNS server on your computer(s) and test if DoH with CloudFlare is working with https://1.1.1.1/help
13. (optional) Add more blocklists and configure the correct time zone
14. (optional Run `Setup_WireGuard.sh` to install WireGuard
15. (optional) Refer to the linuxserver.io's WireGuard image page for using the newly installed WireGuard (link below)
<br /><br />
## Known issues:
1. The NW interface is configured incorrectly if more than one interfaces have assigned IP addreses, other than 127.0.0.1 (e.g. if Docker is already installed)
<br />
The following guides were used as a reference: <br />
https://blog.alexellis.io/hardened-raspberry-pi-nas/ - for the initial OS config and partial hardening <br />
https://www.smarthomebeginner.com/pi-hole-setup-guide/ - sequence of the steps <br />
https://blog.sean-wright.com/dns-with-pi-hole-dnscrypt/ - setting up dnscrypt-proxy <br />
https://github.com/pi-hole/pi-hole/wiki/DNSCrypt-2.0 - setting up dnscrypt-proxy <br />
https://hub.docker.com/r/linuxserver/wireguard - setting up the WireGuard container <br />

