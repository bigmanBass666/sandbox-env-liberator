#!/usr/bin/env python3
import subprocess
import sys
import os
import time

print("=== Testing Redis Advanced Features ===")

# Test 1: Check Redis status
print("\n[1] Checking Redis...")
try:
    result = subprocess.run(['redis-cli', 'ping'], capture_output=True, text=True, timeout=5)
    print(f"  Redis PING: {result.stdout.strip()}")
except Exception as e:
    print(f"  ❌ Error: {e}")

# Test 2: Test streams
print("\n[2] Testing Redis Streams...")
try:
    cmds = [
        ['redis-cli', 'XADD', 'mystream', '*', 'field1', 'value1', 'field2', 'value2'],
        ['redis-cli', 'XLEN', 'mystream'],
        ['redis-cli', 'XREAD', 'COUNT', '2', 'STREAMS', 'mystream', '0']
    ]
    for cmd in cmds:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
        print(f"  {' '.join(cmd)}: {result.stdout.strip()}")
except Exception as e:
    print(f"  ❌ Error: {e}")

# Test 3: Test Lua scripting
print("\n[3] Testing Redis Lua Scripting...")
try:
    script = "return {KEYS[1], ARGV[1]}"
    result = subprocess.run(['redis-cli', 'EVAL', script, '1', 'mykey', 'myarg'], capture_output=True, text=True, timeout=5)
    print(f"  Lua script: {result.stdout.strip()}")
except Exception as e:
    print(f"  ❌ Error: {e}")

# Test 4: Test transactions
print("\n[4] Testing Redis Transactions (MULTI/EXEC)...")
try:
    # Using a here-doc for multi-line redis-cli commands
    multi_cmd = """
MULTI
SET txnkey1 txnval1
INCR txncounter
EXEC
"""
    result = subprocess.run(['redis-cli'], input=multi_cmd, capture_output=True, text=True, timeout=5)
    print(f"  Transaction:\n{result.stdout.strip()}")
except Exception as e:
    print(f"  ❌ Error: {e}")

print("\n=== Done ===")
