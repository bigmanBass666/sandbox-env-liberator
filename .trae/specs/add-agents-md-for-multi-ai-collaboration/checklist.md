# Checklist

## Phase 1: AGENTS.md 核心文件验证

### 内容完整性
- [ ] AGENTS.md 包含项目概述和Polaris北极星目标（彻底解放沙箱）
- [ ] AGENTS.md 包含5个核心快速启动命令（可复制格式，可直接执行）
  - [ ] bootstrap.sh - 一键初始化
  - [ ] full-recon.sh - 环境侦察
  - [ ] fix-network.js - 网络浏览器修复
  - [ ] verify-env.sh - 环境验证
  - [ ] evolve.sh - 进化执行
- [ ] AGENTS.md 包含架构约束和显式边界声明
  - [ ] 能做的操作列表（安装工具、修改配置、修复网络等）
  - [ ] 不能做的操作列表（Docker、内核模块、绕过认证等）
- [ ] AGENTS.md 包含分布式协作规则
  - [ ] GitHub Issue分布式锁机制说明
  - [ ] Artifact Discovery Protocol（搜索顺序：git log → 本地文件系统）
  - [ ] Git提交安全规范（禁止git add -A、检查暂存区等）
- [ ] AGENTS.md 包含Polaris评分系统和进化协议摘要
  - [ ] 6个维度简述（D1-D6）
  - [ ] Per-Round Protocol 9步骤简化版
  - [ ] 反停滞机制（3轮无进展强制轮换等）
- [ ] AGENTS.md 包含代码风格和提交规范
  - [ ] 文件组织规则（工作记录放references/）
  - [ ] Commit message格式

### 质量标准
- [ ] **总行数 < 200行**（严格限制，使用 `wc -l AGENTS.md` 验证）
- [ ] 使用纯Markdown格式（无YAML frontmatter、无特殊语法）
- [ ] 所有命令经过验证（可在项目中直接复制执行）
- [ ] 代码片段来自真实项目（非虚构示例）
- [ ] 人写为主，避免AI自动生成的冗余信息

### 层级关系
- [ ] AGENTS.md 定位清晰为"项目总指挥"（高层概览<200行）
- [ ] 正确引用 SKILL.md 作为详细技术文档（"详见SKILL.md"）
- [ ] 正确引用 .agents/ 子代理目录
- [ ] 不与 SKILL.md 内容重复（各司其职）

---

## Phase 2: 子代理系统验证

### evolution-driver.md
- [ ] YAML frontmatter 完整（name, description, tools, effort, maxTurns）
- [ ] name 字段符合规范（小写+连字符，<64字符）
- [ ] description 清晰描述职责和使用场景（<1024字符）
- [ ] tools 列表遵循最小权限原则（只包含必需工具）
- [ ] 核心职责定义明确（9步Per-Round Protocol）
- [ ] 调用示例真实可用（/evolve 命令、定时任务触发）
- [ ] 输入输出格式清晰（读取polaris-score.md等，产出更新后的状态文件）
- [ ] **行数 < 100行**

### diagnostician.md
- [ ] YAML frontmatter 完整
- [ ] 诊断流程清晰（执行脚本→分析→生成报告）
- [ ] P0-P4优先级分类标准明确
- [ ] 包含真实诊断示例（来自项目实际场景）
- [ ] **行数 < 100行**

### network-fixer.md
- [ ] YAML frontmatter 完整
- [ ] 修复流程完整（代理配置→浏览器安装→依赖修复→CDP连接）
- [ ] 常见问题解决方案库实用（来自SKILL.md Domain 1&5）
- [ ] 命令示例真实可执行
- [ ] **行数 < 100行**

### security-analyst.md
- [ ] YAML frontmatter 完整
- [ ] 安全检查清单完整（seccomp、AppArmor、capabilities、runtime）
- [ ] capabilities解码表准确（与SKILL.md Domain 10一致）
- [ ] 安全评估报告模板实用
- [ ] **行数 < 100行**

### 子代理通用质量
- [ ] 所有子代理都在 .agents/ 目录下
- [ ] 所有子代理都遵循Agent Skills开放规范格式
- [ ] 最权限原则 compliance（无多余工具授权）

---

## Phase 3: 共享记忆系统验证

### 目录结构
- [ ] .context/ 目录已创建
- [ ] activeContext.md 模板已创建（包含会话ID、时间戳、任务状态字段）
- [ ] systemPatterns.md 已创建并预填内容
  - [ ] 包含至少3个已验证的系统模式（从SKILL.md提取）
  - [ ] 示例：CDP连接优势、HTTP代理18080、/tmp清除问题
  - [ ] 格式统一（Pattern名称、发现时间、描述、方案、验证状态、相关域）
- [ ] polaris-score.md 符号链接已创建且正确指向 references/polaris-score.md
- [ ] handoff.md 符号链接已创建且正确指向 references/handoff.md

### .gitignore 更新
- [ ] .context/activeContext.md 已加入 .gitignore
- [ ] .sandbox-persist-test-* 规则保留未删除
- [ ] 其他既有规则不受影响
- [ ] 测试：`git check-ignore .context/activeContext.md` 返回该路径

---

## Phase 4: 集成测试验证

### 场景测试
- [ ] **新AI会话启动场景**：
  - [ ] 读取AGENTS.md后能在2分钟内理解：
    - 项目目标（Polaris北极星）
    - 核心架构（AGENTS.md → SKILL.md → scripts/ → references/）
    - 关键命令（5个快速启动命令）
    - 协作规则（GitHub锁、Artifact Protocol）
    - 如何开始工作（bootstrap → recon → evolve）
- [ ] **子代理调用场景**：
  - [ ] evolution-driver 能完整执行9步进化流程
  - [ ] diagnostician 能生成P0-P4优先级诊断报告
  - [ ] network-fixer 能处理常见网络/浏览器问题
  - [ ] security-analyst 能完成安全评估报告
- [ ] **共享记忆访问场景**：
  - [ ] 通过 .context/polaris-score.md 能访问评分数据
  - [ ] 通过 .context/handoff.md 能访问交接文档
  - [ ] 符号链接有效（不断链）
  - [ ] activeContext.md 不被Git追踪

### 兼容性测试
- [ ] **跨工具兼容性**：
  - [ ] 无特殊语法依赖（纯Markdown + 标准YAML）
  - [ ] Codex能解析（32 KiB限制内，纯Markdown）
  - [ ] Claude Code能解析
  - [ ] Cursor能解析
  - [ ] GitHub Copilot能解析
- [ ] **文件系统兼容性**：
  - [ ] 符号链接在Linux环境下正常工作
  - [ ] 文件路径无特殊字符
  - [ ] 目录权限正确

---

## 实施效果预期验证

### 效率指标
- [ ] 新会话启动时间预期减少 > 25%（基于普林斯顿研究28.64%）
- [ ] Token消耗预期减少 > 15%（基于研究16.58%）
- [ ] 子代理专业化分工降低认知负载
- [ ] 共享记忆减少重复发现已知信息的概率

### 协作质量
- [ ] 跨会话一致性提升（统一的AGENTS.md指导）
- [ ] 子代理输出标准化（明确的输入输出格式）
- [ ] 状态文件访问路径统一（.context/ 入口）
- [ ] Git仓库整洁（activeContext不被追踪，无冗余文件）

### 可维护性
- [ ] 文档结构清晰（AGENTS.md总指挥 → SKILL.md技术细节 → 子代理专业分工）
- [ ] 更新路径明确（AGENTS.md变化少，systemPatterns.md持续累积）
- [ ] 符号链接避免数据冗余（单真相源原则）
