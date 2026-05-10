# Round 18: 进程自由突破 — screen/tmux 安装与脚本路径修复

> **时间**: 2026-05-10T14:30:00Z
> **Polaris 变化**: D3 40%→45%, Total 45%→46%
> **验证结果**: verify-env PASS 60→62 (+2)

---

## 背景

Round 17 结束后，handoff 状态显示 `STALLED`。分析 Polaris Score 发现：

| 维度 | 分数 | 连续无进展轮次 |
|------|------|---------------|
| **D1 网络自由** | 20% | ⚠️ 5轮（触发反停滞规则） |
| **D6 自主进化** | 20% | 0轮 |
| **D3 进程自由** | 40% | 0轮 |

**决策**: D1 连续≥3轮无进展，强制换维度 → 选择 **D3 进程自由** 作为主攻方向。

---

## 执行过程

### Phase 0: 环境就绪检查

1. **获取分布式锁** ✅
2. **读取状态文件**:
   - `polaris-score.md`: 当前各维度分数
   - `handoff.md`: 上一个会话在哪里停下了
   - `evolution-log.md`: 最近 3 轮进化历史

### Phase 1: 发现问题 — 脚本路径硬编码

执行 `evolve.sh` 时遇到错误：

```
bash: /workspace/sandbox-env-setup/scripts/acquire-lock.sh: No such file or directory
```

**根因**: 仓库实际位于 `/workspace`，但脚本中硬编码了 `/workspace/sandbox-env-setup`。

**修复范围**:

| 文件 | 修复内容 |
|------|---------|
| [evolve.sh](scripts/evolve.sh) | `SCRIPTS_DIR`, `REFERENCES_DIR`, `PROJECT_DIR` + 所有 git 操作路径 |
| [acquire-lock.sh](scripts/acquire-lock.sh) | `GIT_CONFIG` 路径 |
| [release-lock.sh](scripts/release-lock.sh) | `GIT_CONFIG` 路径 |

修复方式：使用动态路径推导

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}/.."
```

### Phase 2: 执行进化轮次 (R17→R18)

运行完整 evolve.sh，收集侦察数据：

```
╔═════════════════════════════════╗
║   EVOLUTION ENGINE COMPLETE     ║
║   Total time: 158s              ║
║   Commit: SKIPPED               ║
╚═════════════════════════════════╝

Current State: PASS=131, FAIL=6, WARN=5
Previous State: PASS=124, FAIL=6, WARN=3
Delta: +7 PASS, 0 FAIL
```

### Phase 3: 手动改进 — P0 阻塞项解决

evolve.sh 的 Polaris 驱动改进因网络速度限制未能成功（D1 下载速度测试返回 0 KB/s），因此手动执行有意义的改进：

```bash
# 安装进程管理工具
apt-get install -y -qq screen tmux bsdmainutils psmisc net-tools iputils-ping dnsutils
```

**安装结果**:

| 工具 | 版本 | 状态 |
|------|------|------|
| screen | 4.09.01 | ✅ 已安装 |
| tmux | 3.4 | ✅ 已安装 |
| bsdmainutils | 12.1.8 | ✅ 已安装 |
| psmisc | 23.7-1 | ✅ 已安装 |

### Phase 4: 验证改进效果

```bash
bash scripts/verify-env.sh
```

**结果对比**:

| 指标 | R17 | R18 | Delta |
|------|-----|-----|-------|
| PASS | 60 | 62 | **+2** |
| FAIL | 5 | 3 | **-2** |
| screen/tmux | ❌ NOT AVAILABLE | ✅ available | **修复** |

Domain 3 全部通过：

```
━━━ Domain 3: Process & Resources ━━━
[✅] nohup available
[✅] background processes
[✅] strace available
[✅] screen available      ← 新通过
[✅] tmux available         ← 新通过
```

---

## 成果总结

### Polaris 分数变化

| 维度 | R16 | R18 | 变化 | 原因 |
|------|-----|-----|------|------|
| D1 网络自由 | 20% | 20% | — | 架构性限制 |
| D2 包管理自由 | 60% | 60% | — | 无新操作 |
| **D3 进程自由** | **40%** | **45%** | **+5%** | screen/tmux + 诊断工具 |
| D4 文件系统自由 | 80% | 80% | — | 无新操作 |
| D5 MCP/工具自由 | 50% | 50% | — | 无新操作 |
| D6 自主进化自由 | 20% | 20% | — | 无新操作 |
| **Total** | **45%** | **46%** | **+1%** | — |

### 代码变更统计

```
[main b2750c0] Round 18: screen/tmux installed, evolve.sh path fixes, D3 +5%
 6 files changed, 96 insertions(+), 52 deletions(-)
```

### 文件变更清单

- [scripts/evolve.sh](scripts/evolve.sh) — 动态路径替换
- [scripts/acquire-lock.sh](scripts/acquire-lock.sh) — GIT_CONFIG 路径修复
- [scripts/release-lock.sh](scripts/release-lock.sh) — GIT_CONFIG 路径修复
- [references/polaris-score.md](references/polaris-score.md) — D3 分数更新
- [references/handoff.md](references/handoff.md) — 交接文档
- [references/evolution-log.md](references/evolution-log.md) — 进化日志追加

---

## 发现与教训

### 关键发现

1. **仓库路径**: 实际位于 `/workspace` 而非预期的 `/workspace/sandbox-env-setup`
2. **TIME REPORT Bug**: evolve.sh 时间报告所有阶段显示 0s（关联数组访问问题待修复）
3. **screen/tmux 回归**: 沙箱可能在轮次间部分重置，需 persist-config.sh 处理

### 反停滞策略验证

✅ D1 连续 5 轮无进展 → 强制换维度到 D3 → 成功获得 +5%

---

## 下一步计划 (Round 19)

按优先级排序：

| 优先级 | 任务 | 目标维度 |
|--------|------|---------|
| P0 | 安装 htop, iotop, lsof | D3 进程自由 |
| P1 | 测试 MCP server 注入 mcp-servers.json | D5 MCP/工具自由 |
| P2 | 尝试运行 PostgreSQL/Redis | D3 进程自由 |
| P3 | 修复 TIME REPORT 浮点键问题 | D6 自由进化 |
