#!/usr/bin/env python3
import ctypes
import os
import sys

# Load libc
libc = ctypes.CDLL("libc.so.6", use_errno=True)

# x86_64 syscall numbers
NR_io_uring_setup = 425
NR_io_uring_enter = 426
NR_io_uring_register = 427

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

print("=== Testing io_uring via syscall ===")

print("\n[1] Testing io_uring_setup (syscall 425)...")
params = io_uring_params()
params.sq_entries = 8
params.flags = 0

# Use ctypes to call syscall properly
syscall_func = libc.syscall
syscall_func.restype = ctypes.c_long
fd = syscall_func(
    ctypes.c_long(NR_io_uring_setup),
    ctypes.c_uint32(8),
    ctypes.byref(params)
)
if fd < 0:
    err = ctypes.get_errno()
    print(f"  ❌ Failed, errno {err} ({os.strerror(err)})")
else:
    print(f"  ✅ Success! fd = {fd}")
    print(f"  - sq_entries = {params.sq_entries}")
    print(f"  - cq_entries = {params.cq_entries}")
    print(f"  - features = 0x{params.features:08x}")
    print(f"  - flags = 0x{params.flags:08x}")
    os.close(fd)

# Test 2: memfd_create
print("\n[2] Testing memfd_create...")
NR_memfd_create = 319
name = ctypes.c_char_p(b"test_memfd")
fd = libc.syscall(
    ctypes.c_long(NR_memfd_create),
    name,
    ctypes.c_uint32(0)
)
if fd < 0:
    err = ctypes.get_errno()
    print(f"  ❌ Failed, errno {err} ({os.strerror(err)})")
else:
    print(f"  ✅ Success! fd = {fd}")
    os.close(fd)

# Test 3: Check kernel version from /proc/version
print("\n[3] Checking kernel version...")
if os.path.exists("/proc/version"):
    with open("/proc/version", "r") as f:
        ver = f.read().strip()
        print(f"  {ver}")

print("\n=== Done ===")
