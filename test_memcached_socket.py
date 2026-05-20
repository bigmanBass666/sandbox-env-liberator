#!/usr/bin/env python3
import socket
import time

print("=== Testing Memcached via Socket ===")

sock = None
try:
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(3)
    sock.connect(('localhost', 11211))
    print("  ✅ Connected to memcached!")

    # Set a key
    cmd = b"set mykey 0 3600 5\r\nhello\r\n"
    sock.sendall(cmd)
    resp = sock.recv(1024)
    print(f"  SET response: {resp.decode('utf-8', errors='replace').strip()}")

    # Get the key
    cmd = b"get mykey\r\n"
    sock.sendall(cmd)
    resp = sock.recv(1024)
    print(f"  GET response: {resp.decode('utf-8', errors='replace').strip()}")

except Exception as e:
    print(f"  ❌ Error: {e}")
finally:
    if sock:
        sock.close()

print("\n=== Done ===")
