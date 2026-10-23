# LegacyDisplay Troubleshooting & Setup Guide

---

## 1. Raspberry Pi: Configuring VNC Password Authentication

By default, RealVNC Server on Raspberry Pi OS / Debian uses **UNIX / System Authentication** with proprietary encryption keys. Standard RFC 6143 VNC clients (including LegacyDisplay) require **VNC password** authentication.

### Step-by-Step Instructions:
1. On the Raspberry Pi desktop, open the **RealVNC Server** application (click the VNC icon in the top system tray).
2. Click the **hamburger menu (☰)** in the top-right corner and select **Options**.
3. Select the **Security** tab on the left sidebar:
   - **Encryption**: *Prefer on* or *Let Server Choose*.
   - **Authentication**: Change dropdown from **UNIX password** to **VNC password**.
4. Click **Apply**.
5. A dialog will prompt: *"Specify password for VNC Authentication"*. Enter a password (up to 8 characters for standard RFB compatibility) and confirm it.
6. Click **OK**.
7. Test the configuration from your Windows developer machine:
   ```powershell
   python tools/rfb_probe.py --host <Pi-IP-Address> --port 5900
   ```
   Confirm that `Security Type 2: VNC Authentication` is listed in the output.

---

## 2. Common Errors and Resolutions

### Error: "Unsupported security mode" (Advertised types: [13, 5])
- **Cause**: RealVNC Server is still using UNIX password authentication with proprietary encryption.
- **Resolution**: Follow Section 1 above to enable "VNC password" mode.

### Error: "Connection timed out"
- **Cause**: Device and Raspberry Pi are not on the same Wi-Fi network, or port 5900 is blocked by a firewall.
- **Resolution**:
  - Verify both the iPad and Raspberry Pi are connected to the same local Wi-Fi subnet.
  - On the Pi, check listening ports:
    ```bash
    sudo ss -tulpn | grep 5900
    ```
  - Verify that `ufw` or `iptables` is not blocking incoming TCP traffic on port 5900.

### Error: "Authentication failed"
- **Cause**: Incorrect password entered, or password exceeded 8 characters and was truncated.
- **Resolution**: Standard VNC Authentication (RFC 6143) uses DES with an 8-character password. Verify the password set in RealVNC Server.
