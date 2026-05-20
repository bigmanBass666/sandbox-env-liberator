#!/usr/bin/env python3
import subprocess
import sys

print("=== Testing Memcached ===")

# Try to connect and test
print("\n[1] Testing memcached...")
try:
    # Using netcat to send commands
    cmd = "echo -e 'set mykey 0 3600 5\\r\\nhello\\r\\nget mykey\\r\\n' | nc localhost 11211"
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=5)
    print(f"  Memcached test:\n{result.stdout.strip()}")
except Exception as e:
    print(f"  ❌ Error: {e}")

print("\n=== Done ===")
