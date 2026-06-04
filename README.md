# Setup Pi-Hole 🚀
Automated shell scripts for setting up **Pi-Hole** with **dnscrypt-proxy**, optional **log2ram**, and an optional **WireGuard** container on Raspberry Pi OS (Trixie) and other Debian-based distributions.

## 🏗 Architecture Support & Behavior
The installation process varies depending on your hardware and OS architecture:

*   **64-bit OS (arm64 or amd64):** The script installs Docker and runs Pi-Hole using the official Docker image.
*   **32-bit OS (armhf):** Since Docker is not supported on 32-bit Raspberry Pi OS, the script will trigger an **interactive installation** via `curl -sSL https://install.pi-hole.net | bash`. 
    *   *Note:* During interactive setup, specify `127.0.0.1#54` as the upstream resolver (if you changed the port in `Setup_Pi-hole_vars.sh` replace 54 with the port you chose).
*   **armhf Architecture:** If running on armhf, the script automatically adjusts the dnscrypt-proxy configuration for ARMv6 CPUs (e.g. Pi Zero W) support by downgrading ciphers and changing the upstream resolver to 'cloudflare'.

---

## 🛠 Installation Guide

Follow these steps on a **fresh installation** of Raspberry Pi OS:

- [ ] **1. Prepare SD Card:** Use [Raspberry Pi Imager](https://www.raspberrypi.com/software/) to install **Raspberry Pi OS Lite (minimal)**. Configure your username, (Wi-Fi,) time zone and SSH during this step.
- [ ] **2. Boot & Connect:** Insert the card into your Pi, connect power/Ethernet, and SSH into the device.
- [ ] **3. Prepare Scripts:** Copy `Setup_Pi-Hole.sh` and `Setup_Pi-hole_vars.sh` to the Pi (or `git clone` this repo) and make them executable.
- [ ] **4. Allowlist (Optional):** Populate `AllowList.txt` with any domains you wish to explicitly allow (one per line).
- [ ] **5. WireGuard (64-bit only):** If you want WireGuard, copy `Setup_WireGuard.sh` as well.
- [ ] **6. Configure Variables:** Open `Setup_Pi-hole_vars.sh` with a text editor and adjust settings to your requirements.
- [ ] **7. Run Setup:** Execute the script as root: 
    ```bash
    sudo ./Setup_Pi-Hole.sh
    ```
- [ ] **8. Reboot:** Restart your system once the script finishes.

---

## ⚙️ Post-Installation & Configuration

### 🔑 Accessing Pi-Hole
After installation, the Web UI password is randomly generated.
*   **For 64-bit (Docker):** Find the password via:
    ```bash
    docker container logs pihole 2>&1 | grep password
    ```
*   **To set a new password:**
    *   **64-bit:** `docker container exec -it pihole bash` and then `pihole setpassword`
    *   **32-bit (armhf):** `pihole setpassword`

### ✅ Testing
If using Cloudflare(-security) as the upstream resolver, verify that DNS-over-HTTPS (DoH) is working by visiting: [https://1.1.1.1/help](https://1.1.1.1/help)

### 🛡️ Optional Steps
*   Add additional blocklists in the Pi-Hole UI.
*   Install WireGuard using `sudo ./Setup_WireGuard.sh`.

---

## 💡 Optimization (Recommended for Pi Zero / Low-resource devices)
To reduce CPU and Disk I/O usage on low-power hardware, consider modifying these values in your configuration:

*   `maxDBdays = 7` (Reduces the number of days historic queries are kept; default is 91).
*   `DBinterval = 1800` or `3600` (Changes how often queries are saved to the DB; default is 60 seconds).

---

## ⚠️ Known Issues & Troubleshooting

**Network Interface Configuration (Raspberry Pi only):**  
The NW interface configuration will be skipped if more than one interface has an assigned IP address other than `127.0.0.1` (e.g., if Docker is already installed).

**Port Conflicts:**  
The script checks for ports **53, 80, 443**, and the specified **dnscrypt listen port** (default: 54). The script will abort if any of these are currently in use.

**Systemd-resolved Conflict:**  
On many modern Linux distributions (like Ubuntu), port 53 is occupied by `systemd-resolved`. You must manually disable this service before running the script.

**ARMv6 CPU Performance (e.g., Pi Zero W):**  
`dnscrypt-proxy` with TLS 1.3 can cause an e.g Pi Zero W to stay at ~100% CPU load, making un unusable. The script attempts to mitigate this on `armhf` by forcing TLS 1.2 and the `cloudflare` upstream resolver.  
*Note: This TLS downgrade method may not work in `dnscrypt-proxy` version 2.1.16 or later. Check your `dnscrypt-proxy` version and the official release notes if you encounter issues. The current dnscrypt-proxy version in the Trixie repositories is 2.1.8.*
