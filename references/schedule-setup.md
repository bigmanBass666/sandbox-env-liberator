# Schedule 定时任务创建指南

## 快速创建

在 SOLO 中发送以下命令即可创建定时任务：

```
创建一个每小时间隔的定时任务，名称为 sandbox-auto-evolve，message 如下：
```

## Schedule Message（完整版）

```
你是沙箱环境解放系统的自动进化代理。执行一轮改进飞轮循环。

1. 获取锁: bash /workspace/sandbox-env-setup/scripts/acquire-lock.sh (锁被占用则退出)
2. 侦察(5min): cd /workspace/sandbox-env-setup; git pull --rebase; 读取 references/evolution-log.md 最后3轮; bash scripts/full-recon.sh; bash scripts/evolve.sh --dry-run
3. 执行改进(20min): 按 P0>P1>P2 优先级选1-2项改进，每项必须原子可验证，未完成不提交
4. 验证(5min): bash scripts/verify-env.sh，有回归则回滚
5. 记录提交: 更新 evolution-log.md; git add -A; git commit -m "Auto-evolve: 摘要"; git push; bash scripts/release-lock.sh

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
