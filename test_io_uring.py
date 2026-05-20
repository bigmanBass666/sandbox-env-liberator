#!/usr/bin/env python3
import ctypes
import ctypes.util
import os
import sys
import struct

# Load libc
libc = ctypes.CDLL(ctypes.util.find_library('c'))

# Define types
class io_uring_params(ctypes.Structure):
    _fields_ = [
        ("sq_entries", ctypes.c_uint32),
        ("cq_entries", ctypes.c_uint32),
        ("flags", ctypes.c_uint32),
        ("sq_thread_cpu", ctypes.c_uint32),
        ("sq_thread_idle", ctypes.c_uint32),
        ("features", ctypes.c_uint32),
        ("wq_fd", ctypes.c_uint32),
        ("resv", ctypes.c_uint32 * 3),
        ("sq_off", ctypes.c_uint32 * 4),
        ("cq_off", ctypes.c_uint32 * 4),
    ]

print("=== Testing io_uring ===")

# Test 1: io_uring_setup
print("\n[1] Testing io_uring_setup...")
try:
    params = io_uring_params()
    params.flags = 0
    params.sq_entries = 8
    params.cq_entries = 16

    fd = libc.io_uring_setup(params.sq_entries, ctypes.byref(params))
    if fd < 0:
        print(f"  ❌ io_uring_setup failed: errno {ctypes.get_errno()}")
    else:
        print(f"  ✅ io_uring_setup succeeded! fd = {fd}")
        print(f"  - sq_entries: {params.sq_entries}")
        print(f"  - cq_entries: {params.cq_entries}")
        print(f"  - features: 0x{params.features:x}")

        # Close the fd
        os.close(fd)
except Exception as e:
    print(f"  ❌ Error: {e}")

# Test 2: Check /proc/self/
print("\n[2] Checking /proc/self/...")
for f in ['maps', 'status', 'environ', 'cgroup']:
    try:
        path = f"/proc/self/{f}"
        if os.path.exists(path):
            with open(path, 'rb') as fobj:
                if f in ['maps']:
                    lines = fobj.read().split(b'\n')[:5]
                    print(f"  ✅ /proc/self/{f} has {len(lines)} lines")
                else:
                    print(f"  ✅ /proc/self/{f} exists")
    except Exception as e:
        print(f"  ❌ /proc/self/{f}: {e}")

# Test 3: Check for io_uring in /proc/kallsyms
print("\n[3] Checking /proc/kallsyms for io_uring...")
if os.path.exists("/proc/kallsyms"):
    try:
        with open("/proc/kallsyms", 'r') as f:
            count = 0
            for line in f:
                if 'io_uring' in line:
                    count += 1
            print(f"  ✅ Found {count} io_uring symbols in /proc/kallsyms")
    except Exception as e:
        print(f"  ❌ Error reading /proc/kallsyms: {e}")
else:
    print("  ⚠️  /proc/kallsyms not found")

# Test 4: Check available system calls
print("\n[4] Checking available syscalls...")
syscalls_to_check = ['memfd_create', 'prctl', 'mlock', 'setsid', 'unshare']
for sc in syscalls_to_check:
    try:
        hasattr(libc, sc)
        print(f"  ✅ {sc} available")
    except Exception as e:
        print(f"  ❌ {sc} not available: {e}")

print("\n=== Done ===")
