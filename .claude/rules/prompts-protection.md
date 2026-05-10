---
paths:
  - "prompts/**"
  - "SKILL.md"
---

# System File Protection

- Worker agents MUST NOT modify files in `prompts/` directory
- Worker agents MUST NOT modify `SKILL.md`
- Worker agents MUST NOT modify `evolve.sh` architecture (Phase structure, timing mechanism)
- Only CSO can modify these files
- If a Worker PR contains changes to these files, it should be rejected or those changes reverted
