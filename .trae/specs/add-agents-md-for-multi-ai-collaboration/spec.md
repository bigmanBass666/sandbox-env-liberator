# 多AI协作完整体系引入 Spec

## Why

sandbox-env-liberator 是一个**多AI会话分布式协作项目**，目前只有SKILL.md一个AI指导文件。根据**普林斯顿大学实证研究**和**Agentic AI Foundation标准**，需要建立完整的AI协作体系：

1. **效率提升需求**：AGENTS.md可减少28.64%运行时间+16.58% Token消耗
2. **专业化分工需求**：项目有明确的职能领域（进化执行、诊断、网络修复、安全分析），适合子代理分工
3. **标准化记忆需求**：当前状态文件散落在references/，需要标准化的共享记忆机制
4. **跨会话协作需求**：多个AI会话通过GitHub协作，需要统一的项目理解基础

## What Changes

### 新增文件和目录

**1. 核心文件：AGENTS.md**（项目根目录）
- 长度：<200行纯Markdown
- 定位：项目总指挥（快速入门+关键规则）
- 兼容：20+ AI工具（Codex、Claude Code、Cursor、Copilot等）

**2. 子代理系统：`.agents/` 目录**
- 4个专业化子代理定义：
  - `evolution-driver.md` - Polaris进化执行器
  - `diagnostician.md` - 环境诊断专家
  - `network-fixer.md` - 网络/浏览器修复专家
  - `security-analyst.md` - 安全与隔离分析师
- 格式：Markdown + YAML frontmatter（遵循Agent Skills开放规范）

**3. 共享记忆：`.context/` 目录**
- `activeContext.md` - 当前会话上下文（动态更新）
- `systemPatterns.md` - 已发现的系统模式和workaround
- 符号链接或引用 references/ 中的核心状态文件：
  - → `polaris-score.md` (Polaris评分仪表盘)
  - → `handoff.md` (交接文档)

### 不修改的内容
- ✅ 保持现有 SKILL.md 不变（892行详细技术文档）
- ✅ 保持现有 scripts/ 不变
- ✅ 保持现有 references/ 不变（作为深度参考归档）

### 完整目标目录结构

```
/workspace/
├── AGENTS.md                    # ★ 新增：项目总指挥 (<200行)
├── SKILL.md                     # 已有：技术细节知识库 (892行)
│
├── .agents/                     # ★ 新增：通用子代理定义
│   ├── evolution-driver.md      #   Polaris进化执行器
│   ├── diagnostician.md         #   环境诊断专家
│   ├── network-fixer.md         #   网络/浏览器修复专家
│   └── security-analyst.md      #   安全与隔离分析师
│
├── .context/                    # ★ 新增：标准化共享记忆
│   ├── activeContext.md         #   当前会话上下文
│   ├── systemPatterns.md        #   系统模式库
│   ├── polaris-score.md         #   → 符号链接到 references/
│   └── handoff.md               #   → 符号链接到 references/
│
├── references/                  # 保留：详细参考文档
│   ├── polaris-score.md         # Polaris评分（真相源）
│   ├── handoff.md               # 交接文档（真相源）
│   ├── evolution-log.md         # 进化历史日志
│   ├── capability-matrix.md     # 能力矩阵
│   ├── troubleshooting.md       # 故障排除指南
│   └── ...                      # 其他参考文档
│
├── scripts/                     # 保留：自动化脚本
│   ├── bootstrap.sh
│   ├── full-recon.sh
│   ├── evolve.sh
│   └── ...
│
└── .gitignore                   # 更新：忽略 .context/activeContext.md
```

## Impact

- Affected specs: 无（这是新增能力）
- Affected code: 
  - 新增：AGENTS.md, .agents/*.md, .context/*.md
  - 修改：.gitignore（添加忽略规则）
  - 间接受益：所有新AI会话启动效率提升25%+

## ADDED Requirements

### Requirement 1: AGENTS.md 项目总指挥文件

系统 SHALL 在项目根目录提供 `AGENTS.md` 文件。

#### 质量标准：
- **长度**：<200行（严格限制）
- **格式**：纯Markdown，无YAML frontmatter
- **内容类别**（按优先级）：
  1. ✅ 可复制的命令（bootstrap、recon、fix、verify、evolve）
  2. ✅ 真实代码片段（来自项目的实际示例）
  3. ✅ 显式边界声明（能做/不能做的操作）
  4. ✅ 构建与测试命令及确切标志
  5. ✅ 代码风格规则（Git提交规范、文件组织规则）
  6. ✅ 架构约束（Polaris驱动、分布式锁、Artifact Protocol）

#### 场景1：新AI会话快速启动
- **WHEN** 新的AI会话启动并读取AGENTS.md
- **THEN** 能够在2分钟内理解项目全貌并开始工作

#### 场景2：跨工具兼容性
- **WHEN** 任何兼容AGENTS.md标准的工具访问项目
- **THEN** 能够正确解析指令（无特殊语法依赖）

---

### Requirement 2: 子代理（Sub Agent）系统

系统 SHALL 在 `.agents/` 目录提供专业化子代理定义。

#### 2.1 evolution-driver.md - 进化执行器

**YAML Frontmatter**:
```yaml
---
name: evolution-driver
description: >
  执行Polaris驱动的环境解放进化任务。读取Polaris评分→选择最低分维度
  →形成假设→执行实验→验证改进→更新分数→记录交接。
  遵循Per-Round Protocol的9个步骤。
model: auto
tools:
  - Read
  - Write
  - Bash
  - RunCommand
  - Grep
  - Glob
effort: high
maxTurns: 50
---
```

**核心职责**:
1. 读取状态文件（polaris-score.md, handoff.md, evolution-log.md）
2. 获取分布式锁（acquire-lock.sh）
3. 执行环境侦察（full-recon.sh, deep-recon.sh）
4. 选择进化方向（Polaris最低分维度）
5. 实施改进并验证
6. 更新所有状态文件
7. 提交代码并释放锁

**调用场景**: `/evolve` 命令、定时任务触发、手动启动进化

#### 2.2 diagnostician.md - 诊断专家

**YAML Frontmatter**:
```yaml
---
name: diagnostician
description: >
  环境诊断专家。执行full-recon.sh和deep-recon.sh分析输出，
  识别10个核心域的问题，生成诊断报告和修复建议优先级列表。
model: auto
tools:
  - Read
  - Bash
  - Grep
  - Glob
effort: medium
maxTurns: 20
---
```

**核心职责**:
1. 执行侦察脚本（full-recon.sh, deep-recon.sh）
2. 分析脚本输出，识别问题
3. 检查verify-env.sh的PASS/FAIL项
4. 生成诊断报告（按P0-P4优先级排序）
5. 推荐修复方案

**调用场景**: 新会话启动、环境异常、定期健康检查

#### 2.3 network-fixer.md - 网络修复专家

**YAML Frontmatter**:
```yaml
---
name: network-fixer
description: >
  网络和浏览器修复专家。解决HTTP代理配置、浏览器安装、
  Chrome DevTools连接、CDP端点、缺失系统依赖等问题。
model: auto
tools:
  - Bash
  - RunCommand
  - Write
  - WebFetch
effort: medium
maxTurns: 30
---
```

**核心职责**:
1. 配置HTTP/HTTPS代理（环境变量、npm、git、apt）
2. 安装和配置Chromium浏览器（Playwright）
3. 修复Chrome DevTools Protocol连接（CDP端口9222）
4. 安装缺失的系统依赖库（libxkbcommon0等）
5. 配置镜像源（npm、pip、Go）

**调用场景**: 浏览器无法启动、网络请求失败、MCP连接错误

#### 2.4 security-analyst.md - 安全分析师

**YAML Frontmatter**:
```yaml
---
name: security-analyst
description: >
  容器安全与隔离分析专家。检查seccomp状态、AppArmor配置、
  Linux capabilities、容器运行时识别、系统调用限制，
  评估安全 posture 并提供建议。
model: auto
tools:
  - Read
  - Bash
  - Grep
effort: low
maxTurns: 15
---
```

**核心职责**:
1. 检查seccomp模式（/proc/1/status）
2. 分析AppArmor配置（/proc/1/attr/current）
3. 解码Linux capabilities（CapEff字段）
4. 识别容器运行时（Docker/containerd/K8s）
5. 评估安全限制对任务的影响

**调用场景**: 权限被拒绝错误、安装失败、需要了解安全边界

#### 子代理质量要求：
- 每个子代理 < 100行
- 遵循最小权限原则（只授予必需工具）
- 包含真实调用示例
- 明确输入输出格式

---

### Requirement 3: 共享记忆系统（.context/）

系统 SHALL 提供 `.context/` 目录用于跨会话的共享记忆。

#### 3.1 activeContext.md - 动态上下文

**用途**: 记录当前活跃会话的工作状态
**内容**:
- 会话ID和时间戳
- 正在执行的Task
- 当前进度和发现
- 临时笔记和想法
**生命周期**: 每次会话开始时创建/覆盖
**Git策略**: 加入 .gitignore（不提交）

#### 3.2 systemPatterns.md - 系统模式库

**用途**: 积累已验证的系统行为模式和workarounds
**内容格式**:
```markdown
## Pattern: [模式名称]
- **发现时间**: Round N
- **问题描述**: ...
- **解决方案**: ...
- **验证状态**: VERIFIED / UNVERIFIED / DEPRECATED
- **相关域**: Domain X, Y
```
**示例**:
- CDP连接优于下载Chromium（节省170MB）
- HTTP代理18080是主要网络通道
- /tmp可能被清除，使用/root或/workspace持久化
**更新频率**: 每轮进化结束时追加

#### 3.3 符号链接到核心状态文件

创建符号链接以标准化访问路径：
```bash
.context/polaris-score.md → references/polaris-score.md
.context/handoff.md → references/handoff.md
```
**原因**: 
- .context/ 作为统一的记忆入口
- references/ 继续作为真相源（Git追踪）
- 避免文件冗余和同步问题

---

### Requirement 4: .gitignore 更新

系统 SHALL 更新 `.gitignore` 以支持新的目录结构：

```
# 新增规则
.context/activeContext.md          # 动态上下文（每会话不同）
.sandbox-persist-test-*            # 已有的测试文件（确认保留）
```

## MODIFIED Requirements

无（这是新增能力，不修改现有功能）

## REMOVED Requirements

无

## 设计原则（必须遵守）

1. **从单一AGENTS.md开始** ✓ - 已有SKILL.md，现在补充AGENTS.md
2. **人写为主，AI为辅** ✓ - 核心内容由人设计，AI辅助实现
3. **最小权限** ✓ - 子代理只授予完成任务所需的工具
4. **避免冗余** ✓ - AGENTS.md<200行，SKILL.md保持不变
5. **迭代开发** ✓ - 先创建基础版本，后续持续改进
6. **保持纯Markdown** ✓ - AGENTS.md符合标准格式
7. **KISS原则** ✓ - 只创建必要的目录和文件，不过度设计
