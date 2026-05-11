# ADR-0003: Polaris Scoring System

## Status
Accepted

## Context
需要一个量化指标来衡量 sandbox 解放程度。
主观评估不可重复、不可比较。

## Decision
采用 6 维度 × 100 分制评分体系（Polaris）：

| 维度 | 名称 | 权重 | 当前分数 |
|------|------|------|---------|
| D1 | 网络自由 | 均等 | 40% |
| D2 | 包管理自由 | 均等 | 60% |
| D3 | 进程自由 | 均等 | 45% |
| D4 | 文件系统自由 | 均等 | 80% |
| D5 | MCP/工具自由 | 均等 | 50% |
| D6 | 自主进化自由 | 均等 | 40% |

评分规则：
- New Capability: 正常加分（单维度每轮 max +30%）
- Discovery Bonus: 已知能力重新发现（max +5%）
- Measurement Correction: 更新已知值（delta 不计正增长）
- 总分 = 各维度平均值的四舍五入

## Consequences
**正面**:
- 量化进度可追踪
- 反停滞机制有明确依据
- 不同维度独立推进

**负面**:
- 评分主观性强
- 需要持续维护 Milestone 列表
- 格式错误会导致数据解析问题（已触发 P0 修复）
