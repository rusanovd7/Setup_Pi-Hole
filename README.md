# Setup_Pi-Hole
## A simple Shell script for setting up Pi-Hole with dnscrypt &amp; log2ram and an optional WireGuard container on Raspberry Pi OS

The purpose of the script is to automate the initial configuration of Raspberry Pi OS and the subeseqent instalation of Pi-Hole, dnscrypt-proxy and log2ram with suffictient configuration to run using Cloudflare DoH as the upstream resolver. <br />
There is also an option to install Docker and spin up a WireGuard container using the linuxserver.io image. <br />
This script is intended to be run on a fresh installation of Raspberry Pi OS  Some checks exist, in order to prevent the script from breaking an already configured Pi, but none of them can be considered bulletproof, so running on a Pi with some existing configuration is at your own risk. <br />

Follow these steps to install and configure Pi-Hole on your Raspberry Pi: 

1. Install the Raspberry Pi OS Lite (minimal) image to the MicroSD card
2. If the Raspberry Pi will connect to the network wirelessly, create a wpa_supplicant.conf file in the boot directory. Use the tmpl file and fill the necessary information
3. Create an empty text file named "ssh" (no file extension) in the boot directory
4. Insert the SD card into the Pi and connect power (and Ethernet if not using WiFi)
5. SSH into the Pi with username `pi` and password `raspberry`
6. Copy the scripts `Setup_Pi-Hole.sh` and `Setup_Pi-hole_vars.sh` to a temporary directory on the Raspberry Pi
7. If you would like to install WireGuard, copy `Setup_WireGuard.sh` too
9. Open the script `Setup_Pi-hole_vars.sh` with a text editor and fill/edit the values according to your setup
10. Execute the script as `root` (or with sudo)
11. Reboot
12. Login as `pi` and become `root`. Use the new IP address when connecting
13. Create a password for the new user
14. Exit and login as the new user
15. Execute `sudo userdel pi`
16. After the installation the password for the Pi-Hole Web UI is "pihole". Execute `pihole -a -p` in order to set a new password
17. Configure the Raspberry Pi as the DNS server on your computer(s) and test if DoH with CloudFlare is working with https://1.1.1.1/help
18. (optional) Add more blocklists and configure the correct timezone
19. (optional) Refer to the linuxserver.io's WireGuard image page for using the newly installed WireGuard (link below)

The following guides were used as a reference: <br />
https://blog.alexellis.io/hardened-raspberry-pi-nas/ - for the initial OS config and partial hardening <br />
https://www.smarthomebeginner.com/pi-hole-setup-guide/ - sequence of the steps <br />
https://blog.sean-wright.com/dns-with-pi-hole-dnscrypt/ - setting up dnscrypt-proxy <br />
https://github.com/pi-hole/pi-hole/wiki/DNSCrypt-2.0 - setting up dnscrypt-proxy <br />
https://hub.docker.com/r/linuxserver/wireguard - setting up the WireGuard container <br />
