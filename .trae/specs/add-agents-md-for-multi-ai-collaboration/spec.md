# 引入AGENTS.md提升多AI协作效率 Spec

## Why

sandbox-env-liberator 是一个**多AI会话分布式协作项目**（通过GitHub Issue锁+Polaris驱动进化），但目前**缺少AGENTS.md这个核心文件**。根据普林斯顿大学实证研究，添加高质量的AGENTS.md可以：
- **减少28.64%的运行时间**（98.57秒→70.34秒）
- **减少16.58%的Token消耗**（2925→2440）
- 提升跨会话协作效率（每次新AI会话都能快速理解项目）

当前项目已有完善的SKILL.md（892行详细技术文档），但缺少上层的"项目总指挥"文件来指导AI代理。

## What Changes

- **新增** `/workspace/AGENTS.md` - 项目级AI上下文指令文件（<200行）
  - 遵循Agentic AI Foundation标准（兼容Codex、Claude Code、Cursor等20+工具）
  - 包含6个关键内容类别：可复制命令、代码片段、边界声明、构建测试命令、架构约束
  - 作为SKILL.md的上层补充（不是替代）
  
- **不修改**现有SKILL.md - 保持其作为详细技术参考文档的地位
- **不引入**子代理体系 - 当前阶段复杂度不值得（遵循"从单一AGENTS.md开始"原则）

## Impact

- Affected specs: 无（这是新增能力）
- Affected code: 
  - 新增：`/workspace/AGENTS.md`
  - 间接受益：所有新AI会话启动时读取此文件

## ADDED Requirements

### Requirement: AGENTS.md 核心文件

系统 SHALL 在项目根目录提供 `AGENTS.md` 文件，为AI编程代理提供项目级上下文指令。

#### 场景1：新AI会话快速启动

- **WHEN** 新的AI会话启动并读取项目
- **THEN** AI代理能够在2分钟内理解：
  - 项目目标（Polaris北极星）
  - 核心架构（SKILL.md + 脚本系统 + 参考文档）
  - 关键命令（bootstrap、recon、fix、verify）
  - 分布式协作规则（GitHub锁、Artifact Discovery Protocol）
  - Polaris评分系统和进化协议

#### 场景2：跨工具兼容性

- **WHEN** 任何兼容AGENTS.md标准的工具访问项目（Codex、Claude Code、Cursor、Copilot等）
- **THEN** 能够正确解析和执行文件中的指令

### Requirement: 内容质量标准

AGENTS.md SHALL 遵循以下质量标准：

1. **长度限制**：<200行（当前SKILL.md有892行，需要精炼提取）
2. **格式**：纯Markdown，无YAML frontmatter
3. **内容类别**（优先级排序）：
   - ✅ 可复制的命令（优先于工具名称）
   - ✅ 真实代码片段（优先于纯文本描述）
   - ✅ 显式边界声明（优先于隐式假设）
   - ✅ 构建与测试命令及确切标志
   - ✅ 代码风格规则
   - ✅ 架构约束
4. **人写为主**：核心内容由人起草，AI辅助润色（避免AI自动生成导致的23%成功率下降风险）

### Requirement: 与现有文档的关系

AGENTS.md SHALL 与现有文档形成清晰的层级关系：

```
AGENTS.md (<200行)     ← 项目总指挥：快速入门+关键规则
    ↓ 引用
SKILL.md (892行)       ← 技术细节：完整的10领域知识库
    ↓ 引用
references/*.md        ← 深度参考：评分系统、交接日志、工作记录
scripts/*.sh           ← 执行层：自动化脚本
```

## MODIFIED Requirements

无（这是新增能力，不修改现有功能）

## REMOVED Requirements

无
