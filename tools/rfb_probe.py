#!/usr/bin/env python3
"""
tools/rfb_probe.py
RFB Protocol Handshake Probe for LegacyDisplay
Connects to an RFB/VNC server, reads protocol version, requests supported security types,
and disconnects without sending passwords or credentials.
"""

import socket
import sys
import struct
import argparse

SECURITY_TYPE_NAMES = {
    0: "Invalid / Connection Failed",
    1: "None",
    2: "VNC Authentication (DES challenge-response)",
    5: "RA2",
    6: "RA2ne",
    16: "Tight",
    17: "Ultra",
    18: "TLS",
    19: "VeNCrypt",
    20: "GTK-VNC SASL",
    21: "MD5",
    22: "Colin Dean xvp",
    30: "Apple Remote Desktop",
    33: "RealVNC 33",
    34: "RealVNC 34",
    35: "RealVNC System Auth / RSA-AES",
    128: "RealVNC Single Sign-On",
    129: "RealVNC 129",
    130: "RealVNC 130",
}

def probe_rfb(host: str, port: int = 5900, timeout: float = 5.0, force_version: str = None):
    print(f"[PROBE] Connecting to {host}:{port} (timeout={timeout}s)...")
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(timeout)
    
    try:
        s.connect((host, port))
        print(f"[PROBE] Connected to {host}:{port}")
        
        # 1. Read ProtocolVersion message (12 bytes: e.g. "RFB 003.008\n" or "RFB 005.000\n")
        version_data = s.recv(12)
        if len(version_data) < 12:
            print(f"[ERROR] Received incomplete version string: {version_data}")
            return {"error": "Incomplete version string", "raw": version_data}
        
        version_str = version_data.decode("ascii", errors="replace").strip()
        print(f"[PROBE] Server Protocol Version: '{version_str}'")
        
        # Determine client version:
        # According to RFB spec:
        # If server sends RFB 005.000 or anything >= 3.8, a standard 3.8 client replies RFB 003.008\n
        if force_version:
            client_version = force_version.encode("ascii")
            if not client_version.endswith(b"\n"):
                client_version += b"\n"
        elif "003.007" in version_str:
            client_version = b"RFB 003.007\n"
        elif "003.003" in version_str:
            client_version = b"RFB 003.003\n"
        else:
            # For 003.008, 004.001, 005.000 or higher:
            client_version = b"RFB 003.008\n"
            
        print(f"[PROBE] Sending Client Protocol Version: '{client_version.decode('ascii').strip()}'")
        s.sendall(client_version)
        
        negotiated_str = client_version.decode("ascii").strip()
        
        # 2. Read Security Handshake
        if "003.008" in negotiated_str or "003.007" in negotiated_str:
            num_sec_types_data = s.recv(1)
            if not num_sec_types_data:
                print("[ERROR] Connection closed before receiving security types count.")
                return {"error": "Connection closed prematurely", "version": version_str}
            
            num_sec_types = num_sec_types_data[0]
            print(f"[PROBE] Number of security types advertised: {num_sec_types}")
            
            if num_sec_types == 0:
                # Connection failed, read reason length (uint32) + reason string
                reason_len_data = s.recv(4)
                if len(reason_len_data) == 4:
                    reason_len = struct.unpack(">I", reason_len_data)[0]
                    reason = s.recv(reason_len).decode("latin-1", errors="replace")
                    print(f"[PROBE] Server reported connection failure reason: {reason}")
                    return {"version": version_str, "status": "failed", "reason": reason}
                return {"version": version_str, "status": "failed", "reason": "Unknown (no reason string)"}
            
            sec_types_bytes = s.recv(num_sec_types)
            sec_types = list(sec_types_bytes)
            sec_info = []
            for st in sec_types:
                name = SECURITY_TYPE_NAMES.get(st, f"Unknown/Proprietary ({st})")
                sec_info.append({"id": st, "name": name})
                print(f"[PROBE]   - Security Type {st}: {name}")
                
            return {
                "host": host,
                "port": port,
                "server_version": version_str,
                "client_version": negotiated_str,
                "security_types": sec_info,
                "raw_types": sec_types,
                "has_standard_vnc_auth": 2 in sec_types,
                "has_none_auth": 1 in sec_types
            }
        else:
            # RFB 3.3 sends 4-byte uint32 security type directly
            sec_data = s.recv(4)
            if len(sec_data) == 4:
                sec_type = struct.unpack(">I", sec_data)[0]
                name = SECURITY_TYPE_NAMES.get(sec_type, f"Unknown ({sec_type})")
                print(f"[PROBE] RFB 3.3 Security Type: {sec_type} ({name})")
                return {
                    "host": host,
                    "port": port,
                    "server_version": version_str,
                    "client_version": negotiated_str,
                    "security_types": [{"id": sec_type, "name": name}],
                    "raw_types": [sec_type],
                    "has_standard_vnc_auth": sec_type == 2,
                    "has_none_auth": sec_type == 1
                }
            return {"server_version": version_str, "error": "Incomplete 3.3 security type"}
            
    except socket.timeout:
        print(f"[ERROR] Connection timed out after {timeout} seconds.")
        return {"error": "Connection timed out", "host": host, "port": port}
    except Exception as e:
        print(f"[ERROR] Probe exception: {e}")
        return {"error": str(e), "host": host, "port": port}
    finally:
        s.close()
        print("[PROBE] Socket closed.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="RFB Handshake Probe")
    parser.add_argument("--host", default="172.21.238.234", help="RFB Server Host/IP")
    parser.add_argument("--port", type=int, default=5900, help="RFB Server Port (default 5900)")
    parser.add_argument("--timeout", type=float, default=5.0, help="Timeout in seconds")
    parser.add_argument("--force-version", default=None, help="Force client version (e.g. 'RFB 003.008')")
    args = parser.parse_args()
    
    result = probe_rfb(args.host, args.port, args.timeout, args.force_version)
    print("\n[PROBE SUMMARY]")
    print(result)
