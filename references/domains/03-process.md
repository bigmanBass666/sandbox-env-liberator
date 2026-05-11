# Domain 3: Process & Resources

**What Works**:
- ✅ Background processes (detached with `nohup` + `disown`)
- ✅ `strace`/`ptrace` for debugging
- ✅ All `ulimit` settings unlimited
- ✅ Full `/proc` filesystem access

**What's Limited**:
- ⚠️ 2 CPU cores, 4GB memory (cgroup limits)
- ⚠️ No swap
- ❌ No `screen`/`tmux` (installable via apt)
- ❌ No Docker/Podman (kernel-level restriction)

**Installing screen/tmux**:
```bash
apt-get install -y screen tmux
```

**Running Long-Lived Processes**:
```bash
nohup your_command > /tmp/output.log 2>&1 &
disown
# Check status: cat /tmp/output.log
# Kill: kill $(pgrep -f your_command)
```
