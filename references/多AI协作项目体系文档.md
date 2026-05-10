# 多AI协作项目体系文档

## 一、核心文件：AGENTS.md

### 1.1 什么是 AGENTS.md

`AGENTS.md` 是存放在项目根目录的纯Markdown文件，为AI编程代理提供项目级上下文指令，是跨工具的通用标准，兼容 **Codex、Claude Code、Cursor、GitHub Copilot、Gemini** 等20+种AI工具。目前由 **Agentic AI Foundation（Linux Foundation 旗下）** 进行治理。

### 1.2 编写规范

- **格式**：纯Markdown，无需YAML frontmatter，无需特殊语法
- **大小上限**：OpenAI Codex限 32 KiB
- **建议行数**：保持在200行以内
- **Monorepo支持**：支持多级目录层级，AI读取距当前编辑文件最近的`AGENTS.md`；次一级文件可继承或覆盖上级规则
- **优先级**：最近的`AGENTS.md`覆盖父目录中的设置

**6个显著提升AI性能的内容类别**（基于对2500+仓库的分析）：
1. **可复制粘贴的命令**（优先于工具名称）
2. **真实代码片段**（优先于纯文本描述）
3. **显式边界声明**（优先于隐式假设）
4. 构建与测试命令及确切标志
5. 代码风格规则
6. 架构约束

官方推荐参考：`https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/`

### 1.3 与 CLAUDE.md 的关系

如果你同时使用`CLAUDE.md`（Claude Code的专属指令文件），可以在`CLAUDE.md`中通过 `@AGENTS.md` 引用`AGENTS.md`，维护单一事实来源。

---

## 二、子代理（Subagent）体系

### 2.1 Cursor 子代理

**存放位置**：`.cursor/agents/`

**配置文件格式**（Markdown + YAML frontmatter）：
```yaml
---
name: security-auditor        # 唯一标识（小写+连字符）
description: >
  检测OWASP Top 10漏洞（SQL注入、XSS、硬编码密钥），使用最小权限原则。
model: claude-3-sonnet-20240229  # 可选
tools:                         # 工具授权（最小权限原则）
  - Read
  - Grep
  - Glob
  - Bash
effort: medium                 # low/medium/high
maxTurns: 20                   # 最大交互轮次
---

## 核心职责
1. 审查代码中的安全漏洞
2. 提供修复建议和代码示例
3. 生成详细审计报告

## 审计流程
1. 使用 Grep 搜索敏感关键词
2. 检查输入验证和输出编码
3. 验证权限控制逻辑
4. 扫描依赖包漏洞
```

**调用方式**：`/subagent --name=security-auditor "审查用户认证模块"`

**重要注意**：Cursor在扫描子代理定义时**不跟随符号链接**，请使用真实的`.cursor/agents/`物理目录。

### 2.2 Claude Code 子代理

**存放位置**：`.claude/agents/`（项目级）或 `~/.claude/agents/`（用户级）

**调用方式**：输入 `/agents` 打开管理界面

官方文档：`https://docs.anthropic.com/en/docs/claude-code/sub-agents`

---

## 三、技能文件（SKILL.md）

`SKILL.md` 将专业领域知识封装为可移植的技能包，遵循开放规范，使用渐进式披露模式（4阶段：Advertise → Load → Read resources → Run scripts）。

**目录结构**（以expense-report为例）：
```
expense-report/
├── SKILL.md           # 必需：frontmatter + 指令
├── scripts/           # 可执行代码
│   └── validate.py
├── references/        # 按需加载的参考文档
│   └── POLICY_FAQ.md
└── assets/            # 模板和静态资源
    └── expense-report-template.md
```

**SKILL.md 格式**（必需字段）：
- `name`（必需）：最多64字符，仅小写字母、数字和连字符，必须与父目录名一致
- `description`（必需）：最多1024字符，描述技能功能及使用场景
- `license`（可选）
- `compatibility`（可选）：最多500字符，环境要求
- `metadata`（可选）
- `allowed-tools`（可选）：预批准的工具列表

官方规范网站：`https://agentskills.io/`

---

## 四、研究数据

### 4.1 普鲁斯顿大学实证研究

- **论文标题**：*On the Impact of AGENTS.md Files on the Efficiency of AI Coding Agents*
- **地址**：`https://arxiv.org/abs/2601.20404`
- **实验设计**：在10个仓库、124个Pull Request上运行OpenAI Codex（gpt-5.2-codex），每次任务在隔离Docker环境中分别以有/无AGENTS.md文件两种条件各执行一次
- **关键结果**：
  - 中位运行时间：**98.57秒 → 70.34秒（降幅 28.64%）** 
  - 中位输出Token：**2,925 → 2,440（降幅 16.58%）** 
  - 任务完成行为无显著差异（Wilcoxon signed-rank test）

### 4.2 后续研究

- **地址**：`https://arxiv.org/abs/2602.11988`
- **主要发现**：AI自动生成的AGENTS.md文件可能**降低**任务成功率，成本增加约23%；人工撰写的文件表现更优，成功率平均提升约4%
- **结论**：精心编写的AGENTS.md有帮助；AI自动生成且充满冗余信息的文件反而有害

---

## 五、主要平台官方文档

| 平台/工具 | 资源类型 | 链接 |
|:---|:---|:---|
| **Cursor IDE** | 官方文档 | `https://docs.cursor.com/` |
| **Claude Code (Anthropic)** | 子代理官方文档 | `https://docs.anthropic.com/en/docs/claude-code/sub-agents` |
| **Claude Code (Anthropic)** | SKILL.md与CLAUDE.md文档 | `https://docs.anthropic.com/en/docs/claude-code` |
| **OpenAI Agents SDK** | 官方文档（Python） | `https://openai.github.io/openai-agents-python/` |
| **OpenAI Agents SDK** | PyPI页面 | `https://pypi.org/project/openai-agents/` |
| **Android Studio Gemini** | AGENTS.md配置 | `https://developer.android.google.cn/studio/gemini/agents-md` |
| **Microsoft Agent Framework** | Agent Skills 官方文档 | `https://learn.microsoft.com/en-us/agent-framework/agents/skills` |
| **GitHub Blog** | 如何写出优秀的AGENTS.md（2500+仓库分析） | `https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/` |

---

## 六、关键协议与规范

| 协议/标准 | 全称 | 说明 | 核心链接 |
|:---|:---|:---|:---|
| **A2A** | Agent-to-Agent Protocol | Google开放的Agent间通信协议，基于Protocol Buffer，支持不同框架的Agent直接协作 | `https://github.com/a2aproject/A2A` |
| **Agent Skills** | Agent Skills 开放规范 | 可移植技能包的标准格式（SKILL.md），遵循渐进式披露模式 | `https://agentskills.io/` |
| **OpenAI Agents SDK** | OpenAI官方多Agent编排框架 | 支持Agent配置、工具、护栏、交接、人工介入等功能 | `https://github.com/openai/openai-agents-python` |

---

## 七、设计建议（必须遵守）

- **从单一AGENTS.md开始**：只有在确实需要时才引入子代理和技能文件，避免不必要的复杂度
- **人写为主，AI为辅**：核心架构文件由人起草，AI仅辅助润色和检查一致性
- **迭代开发**：将AGENTS.md视为代码，团队共同审查和改进
- **保持纯Markdown**：遵循AGENTS.md标准格式以确保最大兼容性
- **最小权限**：子代理只授予完成其任务所必需的工具
- **避免冗余**：不将AI自动生成的、充满冗余信息的文件作为主配置使用

---

## 八、项目AI文件Layout推荐

```
project-root/
├── AGENTS.md                    # 项目总指挥：整体架构、通用规则、外部边界
├── .cursor/
│   └── agents/                  # Cursor 子代理
│       ├── code-reviewer.md
│       ├── test-writer.md
│       └── security-auditor.md
├── .claude/
│   ├── agents/                  # Claude Code 子代理
│   │   └── ...
│   └── skills/                  # 按需加载的技能模块
│       └── ...
├── .context/                    # 共享记忆（跨会话+跨Agent上下文延续）
│   ├── activeContext.md
│   ├── systemPatterns.md
│   └── progress.md
└── ...
```
