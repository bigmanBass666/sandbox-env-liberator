#!/usr/bin/env python3
import subprocess
import sys
import os

print("=== Testing PostgreSQL Advanced Features ===")

# Test 1: Check if PostgreSQL is running
print("\n[1] Checking PostgreSQL status...")
try:
    result = subprocess.run(['pg_isready'], capture_output=True, text=True)
    print(f"  {result.stdout.strip()}")
except Exception as e:
    print(f"  ❌ Error: {e}")

# Test 2: Connect and test
print("\n[2] Connecting to PostgreSQL...")
try:
    # Create a test database if not exists
    create_db_cmd = "su - postgres -c \"psql -c 'CREATE DATABASE IF NOT EXISTS test_round83;'\""
    subprocess.run(create_db_cmd, shell=True, capture_output=True)
    
    # Test some queries
    test_queries = [
        "SELECT version();",
        "SELECT current_database();",
        "SELECT now();",
        "SELECT array_agg(x) FROM generate_series(1,5) x;",
        "SELECT jsonb_build_object('key', 'value', 'num', 42);"
    ]
    
    for q in test_queries:
        try:
            cmd = f"su - postgres -c \"psql -d test_round83 -c '{q}' -tA\""
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                print(f"  ✅ Query succeeded: {result.stdout.strip()}")
            else:
                print(f"  ❌ Query failed: {result.stderr.strip()}")
        except Exception as e:
            print(f"  ❌ Exception: {e}")
except Exception as e:
    print(f"  ❌ Error: {e}")

print("\n=== Done ===")
