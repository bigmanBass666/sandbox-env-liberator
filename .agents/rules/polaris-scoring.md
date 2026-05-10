---
paths:
  - "references/polaris-score.md"
  - "references/handoff.md"
  - "references/evolution-log.md"
---

# Polaris Scoring Rules

- **新分数必须对应本轮实际执行的新增能力或可复现验证。**
- | 类型 | 定义 | 评分处理 |
  |------|------|---------|
  | **New Capability** | 本轮安装/配置/启用了之前不存在的能力 | 正常加分 |
  | **Measurement Correction** | 能力一直存在但之前未被发现/未测量 | 更新分数到正确值，History 标注 `(measurement correction)`，Delta 不计入正增长 |
  | **Discovery Bonus** | 首次发现已有能力（一次性奖励） | 最多 +5% discovery bonus |
- **反模式示例**："镜像源 R14 就配好了，R19 只是重新跑了一遍 curl 测速" → Measurement Correction，不是 +20% New Capability。
- "Re-measuring known state" is NOT grounds for score increase
- Score changes must correspond to actually executed new capabilities or reproducible verifications
- When updating polaris-score.md History table, always append new rows — never delete historical rows
- handoff.md Duration must come from `$(date +%s) - START_TIME` — never use estimates like `~10 min`
