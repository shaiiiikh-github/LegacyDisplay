# Project Blockers

This document records genuine external blockers requiring physical hardware or human action, along with precise resolution steps and empirical evidence.

---

## Blocker B1: RealVNC Server Advertises Proprietary Security Types (13, 5)

### Evidence
Running `python tools/rfb_probe.py --host 172.21.238.234 --port 5900` produced:
```
[PROBE] Connecting to 172.21.238.234:5900 (timeout=5.0s)...
[PROBE] Connected to 172.21.238.234:5900
[PROBE] Server Protocol Version: 'RFB 005.000'
[PROBE] Sending Client Protocol Version: 'RFB 003.008'
[PROBE] Number of security types advertised: 2
[PROBE]   - Security Type 13: Unknown/Proprietary (13)
[PROBE]   - Security Type 5: RA2 (RealVNC RSA-AES)
[PROBE] Socket closed.
```

### Analysis
The RealVNC server on Debian (Raspberry Pi OS) is running with default "System authentication" (UNIX credentials). This mode uses RealVNC's closed-source, proprietary public-key protocol (Type 13 / Type 5 RA2) instead of standard RFC 6143 Type 2 (VNC Authentication).

Standard third-party VNC clients (TigerVNC, UltraVNC, LegacyDisplay) cannot authenticate in this mode unless Type 2 is enabled in RealVNC Server settings.

### Resolution Steps (Single Action on the Raspberry Pi)
1. Log into the Raspberry Pi desktop (via local HDMI display or existing working VNC viewer).
2. Right-click or double-click the **VNC Server** icon in the system tray.
3. Open **Options** (via the hamburger menu on the right).
4. Navigate to the **Security** tab.
5. In the **Authentication** dropdown, change from **UNIX password** to **VNC password**.
6. Click **Apply**. When prompted, set a password (e.g. `raspberry` or another password up to 8 characters).
7. Re-run the Windows probe:
   ```powershell
   python tools/rfb_probe.py --host 172.21.238.234 --port 5900
   ```
   Verify that **Security Type 2** appears in the advertised types list.

### Mitigation in Code
The LegacyDisplay iOS client detects when only proprietary types are offered and displays a clear diagnostic alert instructing the user to configure "VNC password" mode on the server. Autonomous client development and testing continue uninterrupted using `tools/mock_rfb_server.py`.
