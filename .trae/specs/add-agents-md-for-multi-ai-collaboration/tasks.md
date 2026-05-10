# Tasks

## Phase 1: 核心基础（AGENTS.md）

- [ ] Task 1: 分析现有文档并提取AGENTS.md核心内容
  - [ ] 1.1 从SKILL.md提取5个核心快速启动命令
    - bootstrap.sh, full-recon.sh, fix-network.js, verify-env.sh, evolve.sh
  - [ ] 1.2 从SKILL.md提取架构约束和边界声明
    - 能做什么：安装工具、修改配置、修复网络、运行进程
    - 不能做什么：Docker、内核模块、绕过认证
  - [ ] 1.3 从references/提取Polaris评分系统和协作规则
    - 6个维度评分、Per-Round Protocol、GitHub锁机制
  - [ ] 1.4 确定AGENTS.md的目标结构（6个内容类别）

- [ ] Task 2: 撰写AGENTS.md文件（目标：<200行）
  - [ ] 2.1 编写项目概述部分（Polaris北极星 + 项目定位）
  - [ ] 2.2 编写快速启动命令区（5个可复制命令+说明）
  - [ ] 2.3 编写架构约束与边界声明区（能做/不能做）
  - [ ] 2.4 编写分布式协作规则区（GitHub锁 + Artifact Protocol）
  - [ ] 2.5 编写Polaris进化协议摘要（9步骤简化版）
  - [ ] 2.6 编写代码风格与提交规范区
  - [ ] 2.7 审查并优化至<200行（删除冗余，保留精华）

## Phase 2: 子代理系统（.agents/）

- [ ] Task 3: 创建 evolution-driver.md 子代理
  - [ ] 3.1 编写YAML frontmatter（name, description, tools, effort, maxTurns）
  - [ ] 3.2 定义核心职责（9步Per-Round Protocol）
  - [ ] 3.3 编写调用示例和工作流程
  - [ ] 3.4 定义输入输出格式（读取哪些文件、产出哪些文件）
  - [ ] 3.5 审查确保<100行且遵循最小权限原则

- [ ] Task 4: 创建 diagnostician.md 子代理
  - [ ] 4.1 编写YAML frontmatter
  - [ ] 4.2 定义诊断流程（执行脚本→分析输出→生成报告）
  - [ ] 4.3 编写P0-P4优先级分类标准
  - [ ] 4.4 包含真实诊断示例
  - [ ] 4.5 审查确保<100行

- [ ] Task 5: 创建 network-fixer.md 子代理
  - [ ] 5.1 编写YAML frontmatter
  - [ ] 5.2 定义修复流程（代理配置→浏览器安装→依赖修复→CDP连接）
  - [ ] 5.3 整理常见问题解决方案库（来自SKILL.md Domain 1&5）
  - [ ] 5.4 包含真实的命令示例
  - [ ] 5.5 审查确保<100行

- [ ] Task 6: 创建 security-analyst.md 子代理
  - [ ] 6.1 编写YAML frontmatter
  - [ ] 6.2 定义安全检查清单（seccomp、AppArmor、capabilities、runtime）
  - [ ] 6.3 整理capabilities解码表（来自SKILL.md Domain 10）
  - [ ] 6.4 编写安全评估报告模板
  - [ ] 6.5 审查确保<100行

## Phase 3: 共享记忆系统（.context/）

- [ ] Task 7: 创建 .context/ 目录结构和文件
  - [ ] 7.1 创建 .context/ 目录
  - [ ] 7.2 创建 activeContext.md 模板（包含会话ID、时间戳、任务状态字段）
  - [ ] 7.3 创建 systemPatterns.md 并预填已知模式（从SKILL.md提取3-5个关键模式）
  - [ ] 7.4 创建符号链接：polaris-score.md → references/polaris-score.md
  - [ ] 7.5 创建符号链接：handoff.md → references/handoff.md

- [ ] Task 8: 更新 .gitignore
  - [ ] 8.1 添加 .context/activeContext.md 忽略规则
  - [ ] 8.2 确认现有的 .sandbox-persist-test-* 规则保留
  - [ ] 8.3 验证其他规则不受影响

## Phase 4: 集成验证

- [ ] Task 9: 文档质量验证
  - [ ] 9.1 检查 AGENTS.md 行数（必须 < 200行）
  - [ ] 9.2 检查所有子代理行数（每个 < 100行）
  - [ ] 9.3 验证AGENTS.md的6个内容类别完整性
  - [ ] 9.4 验证子代理的最小权限原则 compliance
  - [ ] 9.5 检查纯Markdown格式合规性（无特殊语法依赖）

- [ ] Task 10: 集成测试
  - [ ] 10.1 模拟新AI会话启动场景（读取AGENTS.md → 2分钟理解项目）
  - [ ] 10.2 测试子代理调用场景（模拟4个子代理的工作流）
  - [ ] 10.3 验证共享记忆系统的访问路径（.context/ 符号链接正确）
  - [ ] 10.4 测试跨工具兼容性（假设不同AI工具读取）
  - [ ] 10.5 验证Git忽略规则生效（activeContext不被追踪）

# Task Dependencies

## 串行依赖（必须按顺序）
- [Task 2] depends on [Task 1]
- [Task 9] depends on [Task 2, Task 3, Task 4, Task 5, Task 6, Task 7, Task 8]
- [Task 10] depends on [Task 9]

## 并行执行（可同时进行）
- [Task 3], [Task 4], [Task 5], [Task 6] 可并行（子代理之间无依赖）
- [Task 7], [Task 8] 可并行（目录结构和gitignore独立）
- [Task 7] 可与 [Task 3-6] 并行（共享记忆与子代理独立）

## 推荐执行顺序
```
Phase 1 (串行): Task 1 → Task 2
Phase 2 (并行): Task 3 + Task 4 + Task 5 + Task 6
Phase 3 (并行): Task 7 + Task 8 (可与Phase 2同时进行)
Phase 4 (串行): Task 9 → Task 10
```

**预计总任务数**: 10个主任务 + 40+个子任务
**预计并行度**: Phase 2可4路并行，Phase 3可2路并行
