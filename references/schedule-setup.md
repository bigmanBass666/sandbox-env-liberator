# Schedule 定时任务创建指南

## 快速创建

在 SOLO 中发送以下命令即可创建定时任务：

```
创建一个每小时间隔的定时任务，名称为 sandbox-auto-evolve，message 如下：
```

## Schedule Message（完整版）

```
你是 sandbox-env-liberator 的自动进化 Worker。执行一轮改进飞轮循环。

⏱️ 时间硬约束：总会话 ≤50 分钟，必须在下一轮触发前完成 git push + release-lock。

1. 环境准备: cd /workspace; git fetch origin; git checkout worker; git pull origin worker
2. 读取状态: cat references/polaris-score.md; cat references/handoff.md; tail -100 references/evolution-log.md
3. 执行进化: bash scripts/evolve.sh（必经步骤！不可跳过。TIME REPORT 是 Step 4 的输入）
4. 持续改进: evolve.sh 完成后，继续主动关闭 polaris-score.md 中的 Milestone 差距
   - 读 polaris-score.md → 找最低分维度 → 尝试关闭下一个 Milestone
   - 每完成一个 Milestone 就 commit 一次
   - 反复循环直到时间用尽或所有 Milestone 被阻塞
5. 记录提交: 更新 evolution-log.md; git add references/; git commit -m "Round N: 摘要"; git push origin worker; bash scripts/release-lock.sh

⚠️ 跳过 evolve.sh = 提交将被 revert + 下一轮需重做

异常: 锁超时自动释放 | 时间耗尽保存已完成部分 | Git冲突以远程为准 | 退出前必须release-lock
```

## Cron 表达式

```
0 * * * *
```

含义：每小时的第0分钟触发

## 时区

Asia/Shanghai

## 手动触发

创建后可通过 `action: "trigger"` 立即触发一次测试运行。
