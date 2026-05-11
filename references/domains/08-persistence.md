# Domain 8: Persistence & Session Recovery

**What Persists Across Sessions**:
- ✅ Files in `/workspace` and `/root`
- ✅ Shell profiles (`.bashrc`, `.zshrc`, `.profile`)
- ✅ npm global packages
- ✅ mise-managed tool versions
- ✅ SSH keys
- ❓ `/tmp` may be cleared

**Maximizing Persistence** (automated by persist-config.sh):

```bash
# 1. Add environment setup to shell profiles
bash /workspace/sandbox-env-setup/scripts/persist-config.sh

# 2. In a new session, restore environment
source /usr/local/bin/sandbox-env-setup.sh

# 3. Quick re-setup if needed
bash /workspace/sandbox-env-setup/scripts/full-recon.sh  # Re-diagnose
node /workspace/sandbox-env-setup/scripts/fix-network.js  # Re-fix
```

**Session Recovery Checklist**:
1. Source environment setup script
2. Verify browser works (`npx playwright install chromium` if needed)
3. Re-install any missing apt packages
4. Restore environment variables from saved config
