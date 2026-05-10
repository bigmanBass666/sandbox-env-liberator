# Handoff Record

> 每个进化会话结束时必须更新此文件。这是给下一个会话（可能是全新的 AI）的交接单。

## Session Info

| Field | Value |
|-------|-------|
| Round | _ |
| Ended At | _ |
| Commit | _ |
| Duration | _ |
| Status | COMPLETE / STALLED / INCOMPLETE / CRASHED |
| Polaris Focus Dimension | _ |
| Polaris Delta This Round | _ |

## What I Was Doing When I Stopped

_（描述本轮主攻方向和最后在做的事情）_

## Completed This Round

- [ ] _
- [ ] _

## What's Left Undone (for next session)

> 这些是下一个会话应该优先处理的事项。按优先级排序。

- [ ] **[P0]** _（最高优先级 — 直接继续这项工作）_
- [ ] **[P1]** _
- [ ] **[P2]] _
- [ ] **[P3]] _

## Blockers / Risks

| Item | Severity | Description | Mitigation |
|------|----------|-------------|------------|
| _ | HIGH/MED/LOW | _ | _ |

## Discoveries Worth Following Up

| Discovery | Potential Impact | Suggested Action |
|-----------|-----------------|------------------|
| _ | _ | _ |

## Environment Notes

_（任何环境变化、回归、需要注意的异常）_

---

## Template Instructions

When filling out this handoff:
1. **Session Info**: Always fill completely. Duration from TIME REPORT.
2. **What I Was Doing**: Be specific — which dimension, which milestone, what was the last action.
3. **What's Left Undone**: These become the next session's starting point. Make them actionable.
4. **Blockers**: If something blocked progress, document it so the next session doesn't waste time rediscovering it.
5. **Polaris Delta**: Which dimensions changed and by how much. Reference polars-score.md.
6. **Status meanings**:
   - `COMPLETE`: Round finished normally, all intended work done
   - `STALLED`: No more ideas, need external input (meta prompt should provide new direction)
   - `INCOMPLETE`: Time ran out, work in progress
   - `CRASHED`: Session ended unexpectedly (check for uncommitted changes)
