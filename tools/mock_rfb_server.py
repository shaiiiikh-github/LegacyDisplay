#!/usr/bin/env python3
"""
tools/mock_rfb_server.py
Mock RFB 3.8 Server for testing LegacyDisplay RFB client without physical hardware.
Supports RFB 3.8, VNC Authentication (Type 2) and None (Type 1), ServerInit, and Framebuffer updates.
"""

import socket
import struct
import threading
import sys
import argparse
import os

# Try importing RFB probe helper or implement DES verification
try:
    from rfb_probe import SECURITY_TYPE_NAMES
except ImportError:
    SECURITY_TYPE_NAMES = {}

class MockRFBServer:
    def __init__(self, host="127.0.0.1", port=5901, auth_type=2, password="password", width=800, height=600):
        self.host = host
        self.port = port
        self.auth_type = auth_type # 1 = None, 2 = VNC Auth
        self.password = password
        self.width = width
        self.height = height
        self.running = False
        self.server_socket = None

    def start(self):
        self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.server_socket.bind((self.host, self.port))
        self.server_socket.listen(5)
        self.running = True
        print(f"[MOCK RFB] Server listening on {self.host}:{self.port} (auth_type={self.auth_type})")

        while self.running:
            try:
                client_sock, client_addr = self.server_socket.accept()
                print(f"[MOCK RFB] Accepted client connection from {client_addr}")
                t = threading.Thread(target=self.handle_client, args=(client_sock,), daemon=True)
                t.start()
            except Exception as e:
                if self.running:
                    print(f"[MOCK RFB] Accept error: {e}")
                break

    def stop(self):
        self.running = False
        if self.server_socket:
            self.server_socket.close()

    def handle_client(self, sock: socket.socket):
        try:
            sock.settimeout(10.0)
            
            # 1. ProtocolVersion
            sock.sendall(b"RFB 003.008\n")
            client_ver = sock.recv(12)
            print(f"[MOCK RFB] Client offered version: {client_ver.decode('ascii', errors='replace').strip()}")

            # 2. Security Handshake
            if self.auth_type == 1:
                # Offer None (1)
                sock.sendall(bytes([1, 1]))
                chosen = sock.recv(1)[0]
                print(f"[MOCK RFB] Client chose security type: {chosen}")
                # In 3.8, send SecurityResult (0 = OK)
                sock.sendall(struct.pack(">I", 0))

            elif self.auth_type == 2:
                # Offer VNC Auth (2)
                sock.sendall(bytes([1, 2]))
                chosen = sock.recv(1)[0]
                print(f"[MOCK RFB] Client chose security type: {chosen}")
                
                # Send 16-byte random challenge
                challenge = os.urandom(16)
                sock.sendall(challenge)
                
                # Receive 16-byte response
                response = sock.recv(16)
                print(f"[MOCK RFB] Received 16-byte challenge response: {response.hex()}")
                
                # Accept response
                sock.sendall(struct.pack(">I", 0))

            # 3. ClientInit
            shared = sock.recv(1)[0]
            print(f"[MOCK RFB] ClientInit shared-flag: {shared}")

            # 4. ServerInit: width(2), height(2), pixelformat(16), name_length(4), name
            name = b"Mock Pi Desktop"
            # 32-bit pixel format: bpp=32, depth=24, be=0, tc=1, rMax=255, gMax=255, bMax=255, rShift=16, gShift=8, bShift=0
            pf = struct.pack(">BBBBHHHBBB3s", 32, 24, 0, 1, 255, 255, 255, 16, 8, 0, b"\x00\x00\x00")
            server_init = struct.pack(">HH", self.width, self.height) + pf + struct.pack(">I", len(name)) + name
            sock.sendall(server_init)
            print(f"[MOCK RFB] Sent ServerInit for {self.width}x{self.height} desktop '{name.decode()}'")

            # 5. Message Loop
            while self.running:
                msg_type_data = sock.recv(1)
                if not msg_type_data:
                    break
                msg_type = msg_type_data[0]

                if msg_type == 0: # SetPixelFormat
                    pf_data = sock.recv(19) # 3 padding + 16 pf
                elif msg_type == 2: # SetEncodings
                    pad = sock.recv(1)
                    num_enc = struct.unpack(">H", sock.recv(2))[0]
                    encs = sock.recv(num_enc * 4)
                    print(f"[MOCK RFB] Client requested {num_enc} encodings")
                elif msg_type == 3: # FramebufferUpdateRequest
                    req_data = sock.recv(9)
                    inc, rx, ry, rw, rh = struct.unpack(">BHHHH", req_data)
                    # Send FramebufferUpdate with 1 raw rectangle
                    self.send_test_framebuffer(sock, rx, ry, rw, rh)
                elif msg_type == 4: # KeyEvent
                    key_data = sock.recv(7)
                    down, _, sym = struct.unpack(">BBH", key_data[:4])
                    sym = struct.unpack(">I", key_data[3:7])[0]
                    # print(f"[MOCK RFB] Key event: down={down}, sym=0x{sym:X}")
                elif msg_type == 5: # PointerEvent
                    ptr_data = sock.recv(5)
                    mask, px, py = struct.unpack(">BHH", ptr_data)
                    # print(f"[MOCK RFB] Pointer: mask={mask}, x={px}, y={py}")

        except Exception as e:
            print(f"[MOCK RFB] Session ended: {e}")
        finally:
            sock.close()
            print("[MOCK RFB] Client socket closed.")

    def send_test_framebuffer(self, sock: socket.socket, x: int, y: int, w: int, h: int):
        # FramebufferUpdate header: msg-type(1)=0, pad(1)=0, rect-count(2)=1
        header = struct.pack(">BBH", 0, 0, 1)
        # Rect header: x(2), y(2), w(2), h(2), encoding(4)=0 (Raw)
        rect_header = struct.pack(">HHHHl", x, y, w, h, 0)
        
        # Generate simple test pattern: color bars (32-bit BGRA)
        # Blue: 0xFF, 0x00, 0x00, 0x00; Green: 0x00, 0xFF, 0x00, 0x00; Red: 0x00, 0x00, 0xFF, 0x00
        line_bytes = bytearray()
        for col in range(w):
            if col < w // 3:
                line_bytes.extend(b"\xFF\x00\x00\xFF") # Blue
            elif col < (2 * w) // 3:
                line_bytes.extend(b"\x00\xFF\x00\xFF") # Green
            else:
                line_bytes.extend(b"\x00\x00\xFF\xFF") # Red

        raw_data = bytes(line_bytes) * h
        sock.sendall(header + rect_header + raw_data)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Mock RFB 3.8 Server")
    parser.add_argument("--port", type=int, default=5901, help="Port to listen on (default 5901)")
    parser.add_argument("--auth", type=int, default=2, choices=[1, 2], help="Auth type: 1=None, 2=VNC Auth")
    args = parser.parse_args()

    server = MockRFBServer(port=args.port, auth_type=args.auth)
    try:
        server.start()
    except KeyboardInterrupt:
        server.stop()
