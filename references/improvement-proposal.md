# Project Improvement Proposal

> **Author**: CSO Analysis
> **Date**: 2026-05-11
> **Type**: Architecture & Code Quality Improvements
> **Priority**: P1-P2

## Executive Summary

Analysis of the `sandbox-env-liberator` project reveals several areas for improvement in code structure, verification consistency, documentation, and automation. This proposal outlines specific, actionable improvements organized by priority.

---

## 1. Code Structure Issues

### 1.1 Refactor evolve.sh Phase 7 into Modular Strategy Scripts

**Problem**: Phase 7 in `evolve.sh` contains 1400+ lines with mixed responsibilities:
- D1/D5/D6 implementations are placeholder `echo` statements
- Continue-loop improvement strategy is overly simplistic
- Hard to maintain and extend

**Proposed Structure**:

```
scripts/
  evolve.sh              # Main pipeline (~400 lines)
  strategies/             # Improvement strategy modules
    d1-network.sh
    d2-packages.sh
    d3-process.sh
    d4-filesystem.sh
    d5-mcp.sh
    d6-evolution.sh
  lib/
    polaris-lib.sh       # Polaris scoring functions
    phase-common.sh      # Shared phase utilities
```

**Benefits**:
- Separation of concerns
- Easier to test individual strategies
- Better extensibility for new dimensions

**Status**: Recommended for Phase 8+ implementation

### 1.2 Fix Temporary File Cleanup in full-recon.sh

**Location**: [full-recon.sh:L104](scripts/full-recon.sh#L104)

The script creates `/tmp/go_net_check.go` but cleanup is not guaranteed.

**Fix**: Add cleanup in a trap handler:
```bash
trap 'rm -f /tmp/go_net_check.go /tmp/sandbox-recon/*.tmp 2>/dev/null' EXIT
```

---

## 2. Verification System Inconsistencies

### 2.1 Domain Numbering Mismatch

| Script | Domain Range |
|--------|-------------|
| full-recon.sh | Domain 1-10 |
| verify-env.sh | Domain 1-12 |

**Issue**: verify-env.sh extends coverage to Node.js capabilities and performance baseline, but full-recon.sh doesn't sync these additions.

**Recommendation**: Unify domain definitions in `references/domains/00-capability-matrix.md` and ensure both scripts reference the same structure.

### 2.2 Fix polaris-score.md History Table Format

**Location**: [polaris-score.md:L122-143](references/polaris-score.md#L122-L143)

**Issue**: Table header and data columns are misaligned:

```markdown
# Current (incorrect)
| Round | Total | D1 | D2 | D3 | D4 | D5 | D6 | Notes |
| R43 | 40 | 60 | 45 | 80 | 50 | 40 |

# Should be (correct)
| Round | D1 | D2 | D3 | D4 | D5 | D6 | Total | Notes |
| R43 | 40 | 60 | 45 | 80 | 50 | 40 | 53% |
```

**Fix Required**:
1. Correct column order in header
2. Add missing Total values to data rows
3. Add `notes` column data (or mark as "N/A")

---

## 3. Polaris Scoring System Improvements

### 3.1 Automate Score Updates

**Problem**: Scoring requires manual updates to `polaris-score.md`, prone to errors and omissions.

**Proposed Solution**: Add automatic score update trigger in Phase 7:

```bash
# After successful improvement
if [ "$IMPROVE_SUCCESS" = true ]; then
    bash "$SCRIPTS_DIR/update-polaris-score.sh" \
        --dimension "$POLARIS_FOCUS_DIM" \
        --evidence "$IMPROVE_EVIDENCE"
fi
```

**Benefits**:
- Ensures score reflects actual improvements
- Creates audit trail in evolution-log
- Reduces manual error

### 3.2 Implement D5 MCP Injection Automation

**Location**: [evolve.sh:L1226-1256](scripts/evolve.sh#L1226-L1256)

**Issue**: D5 milestone states:
> [ ] [60%] Successfully inject custom MCP server and verify it works

Current implementation only tests JSON file write, doesn't verify actual MCP server injection.

**Required Implementation**:
1. Create a test MCP server definition
2. Inject into mcp-servers.json
3. Verify server can be loaded by MCP infrastructure
4. Clean up test entry

---

## 4. Git Workflow Improvements

### 4.1 Worker → Main Merge Automation

**Current State**: Manual CSO merge required
**Issue**: No automated PR creation or merge conditions

**Proposed Enhancement**:
1. Worker pushes trigger CI/CD check
2. Guardrails validation (syntax check, forbidden files)
3. If all checks pass → auto-create PR for CSO review
4. CSO approval → merge

### 4.2 Evolution Log Completeness

**Issue**: Timeline shows missing rounds (e.g., round-41-session-debug-log.md doesn't exist)

**Recommendation**:
- Add guardrail: warn if timeline-round-{N}.jsonl is missing after N+1
- Ensure evolution-log.md entries contain actual change details, not just "Polaris integration active"

---

## 5. Reliability Improvements

### 5.1 Consolidate Timeout Constants

**Issue**: Different timeout values across scripts:

| Location | Timeout |
|----------|---------|
| full-recon.sh:4.8 | 5000ms |
| verify-env.sh:74 | 8000ms |
| evolve.sh:26 | TIMEOUT_SECS=120 |

**Solution**: Create centralized config:
```bash
# scripts/lib/config.sh
readonly NETWORK_TIMEOUT_SHORT=5000
readonly NETWORK_TIMEOUT_MEDIUM=10000
readonly NETWORK_TIMEOUT_LONG=30000
readonly PHASE_TIMEOUT=120
```

### 5.2 Distinguish Error Severity

**Current**: Heavy use of `|| true` hides errors:
```bash
bash "$SCRIPTS_DIR/full-recon.sh" 2>&1 || true
```

**Proposed**: Distinguish fatal vs. non-fatal errors:
```bash
# Fatal: script missing or corrupted
# Non-fatal: network timeout, optional check failed

if ! bash "$SCRIPTS_DIR/full-recon.sh" 2>&1; then
    case $? in
        124) echo "Warning: timeout, using cached results" ;;
        *)   echo "Error: full-recon failed"; return 1 ;;
    esac
fi
```

---

## 6. Documentation Improvements

### 6.1 Clarify Documentation Responsibilities

**Issue**:
- `CLAUDE.md` exists but content is unclear
- `AGENTS.md` is the primary documentation
- No `.claude.json` for Claude Code configuration

**Recommendation**:
- Consolidate into single source of truth (AGENTS.md)
- Add `.claude.json` for Claude Code integration
- Archive or remove CLAUDE.md

### 6.2 Add Architecture Decision Records (ADR)

**Issue**: Important decisions are documented in code comments or chat, not discoverable.

**Proposed**: Create `references/adr/` directory:
```
references/adr/
  0001-github-as-source-of-truth.md
  0002-multi-agent-roles.md
  0003-polars-scoring-system.md
  0004-evolve-sh-pipeline.md
```

**ADR Template**:
```markdown
# ADR-XXXX: Title

## Status
Proposed | Accepted | Deprecated

## Context
What is the issue?

## Decision
What is the change?

## Consequences
What becomes easier? What becomes harder?
```

---

## 7. Priority Summary

| Priority | Item | Impact | Effort |
|----------|------|--------|--------|
| P0 | Fix polaris-score.md table format | Data accuracy | Low |
| P1 | Refactor Phase 7 into strategy modules | Maintainability | Medium |
| P1 | Implement D5 MCP injection test | D5 progress | Medium |
| P2 | Consolidate timeout constants | Reliability | Low |
| P2 | Add Architecture Decision Records | Knowledge sharing | Low |
| P3 | Worker→main merge automation | Automation | High |

---

## 8. Files Affected

| File | Changes |
|------|---------|
| `references/polaris-score.md` | Table format fix |
| `scripts/evolve.sh` | (No changes in this PR - planning only) |
| `references/improvement-proposal.md` | This document |

---

## 9. Checklist

- [x] Document created
- [ ] Review by CSO
- [ ] Prioritize items
- [ ] Assign to implementation phases
