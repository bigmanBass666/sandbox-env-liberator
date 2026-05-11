# Domain 10: Security & Isolation

**Key Insight**: Understanding the container's security posture — seccomp, AppArmor, capabilities, and isolation mechanisms — is critical for advanced operations and troubleshooting permission-denied errors.

**seccomp Status**:
- Check: `/proc/1/status` → Seccomp line
- Values: 0=disabled, 1=strict, 2=filtered

**AppArmor**:
- Check: `/proc/1/attr/current`
- May show "unconfined" or a specific profile

**Linux Capabilities Breakdown**:
- CapEff: `0xa80425fb` (current environment)
- Decoded capabilities:
  - CAP_CHOWN, CAP_DAC_OVERRIDE, CAP_FOWNER, CAP_FSETID
  - CAP_KILL, CAP_SETGID, CAP_SETUID, CAP_SETPCAP
  - CAP_NET_BIND_SERVICE, CAP_NET_RAW
  - CAP_SYS_CHROOT, CAP_MKNOD, CAP_AUDIT_WRITE, CAP_SETFCAP
- Missing capabilities:
  - CAP_SYS_ADMIN, CAP_SYS_PTRACE (partial), CAP_NET_ADMIN, CAP_SYS_RESOURCE

**Container Runtime Identification**:
- Docker: Check `/.dockerenv`
- containerd: Check `/run/container_type`
- Kubernetes: Check `KUBERNETES_SERVICE_HOST`
- cgroup info: `/proc/1/cgroup`

**System Call Restrictions**:
- `strace` available for tracing
- Some syscalls filtered by seccomp (mount, umount, pivot_root, reboot, etc.)
- Network-related syscalls (socket, bind, listen, connect) available at application level

**Node.js Security Capabilities**:
- 28 core modules all available
- WebCrypto API available
- `worker_threads` available (multi-threading)
- Native WebSocket available
- 52 cryptographic algorithms
