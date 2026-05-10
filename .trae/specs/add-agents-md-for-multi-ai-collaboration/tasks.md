# Tasks

- [ ] Task 1: 分析现有项目文档并提取AGENTS.md核心内容
  - [ ] 1.1 从SKILL.md提取关键命令（bootstrap、recon、fix、verify）
  - [ ] 1.2 从SKILL.md提取架构约束和边界声明
  - [ ] 1.3 从references/提取Polaris评分系统和协作规则
  - [ ] 1.4 确定AGENTS.md的目标受众（新AI会话启动场景）

- [ ] Task 2: 撰写AGENTS.md文件（<200行，遵循6个内容类别）
  - [ ] 2.1 编写项目概述和目标（Polaris北极星）部分
  - [ ] 2.2 编写快速启动命令（5个核心命令+说明）
  - [ ] 2.3 编写架构约束和边界声明（能做/不能做什么）
  - [ ] 2.4 编写分布式协作规则（GitHub锁、Artifact Protocol）
  - [ ] 2.5 编写Polaris评分系统和进化协议摘要
  - [ ] 2.6 编写代码风格和提交规范
  - [ ] 2.7 审查并确保总行数<200行

- [ ] Task 3: 验证AGENTS.md质量
  - [ ] 3.1 检查行数限制（必须<200行）
  - [ ] 3.2 验证6个内容类别是否完整
  - [ ] 3.3 测试可复制命令的正确性
  - [ ] 3.4 确认与SKILL.md的层级关系清晰
  - [ ] 3.5 检查是否符合Agentic AI Foundation标准（纯Markdown格式）

- [ ] Task 4: 文档集成测试
  - [ ] 4.1 模拟新AI会话读取AGENTS.md的场景
  - [ ] 4.2 验证能否在2分钟内理解项目全貌
  - [ ] 4.3 检查跨工具兼容性（无特殊语法依赖）

# Task Dependencies
- [Task 2] depends on [Task 1]
- [Task 3] depends on [Task 2]
- [Task 4] depends on [Task 3]
