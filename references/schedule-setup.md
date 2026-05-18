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
3. 执行进化: bash scripts/evolve.sh（TIME_BUDGET=2700s，含多轮 continue loop）
4. 📋 **[CSO 指定任务] CDN 速度普查** ← 本轮必做！
   先读 references/schedule-setup.md 获取完整任务详情。
   对以下 12 个域名逐一通过 egress proxy (127.0.0.1:18080) 测速：

   目标列表:
   | # | 域名 | 类型 |
   |---|------|------|
   | 1 | https://dl.google.com/android/repository/repository2-3.xml | Google CDN |
   | 2 | https://storage.googleapis.com | Google Cloud Storage |
   | 3 | https://github.com | GitHub 主站 |
   | 4 | https://objects.githubusercontent.com | GitHub 对象存储 |
   | 5 | https://registry.npmjs.org | npm 官方源 |
   | 6 | https://npmmirror.com/mirrors/npm/index.json | npm 镜像(中国) |
   | 7 | https://crates.io/api/v1/summary | Rust/Cargo 官方 |
   | 8 | https://rsproxy.cn/api/v1/crates | Rust 镜像(中国) |
   | 9 | https://files.pythonhosted.org/packages/PyYAML-6.0.1.tar.gz | PyPI 官方 |
   |10 | https://pypi.tuna.tsinghua.edu.cn/simple | PyPI 镜像(中国) |
   |11 | https://dl-cdn.alpinelinux.com/alpine/v3.19/main/x86_64/APKINDEX.tar.gz | Alpine Linux |
   |12 | https://httpbin.org/get | 国际基准站点 |

   测速命令模板:
   curl -x http://127.0.0.1:18080 -I --connect-timeout 10 \
     -w '%{time_total}s %{speed_download}B/s HTTP/%{http_code}\n' \
     '<URL>' 2>&1

   输出格式: 写入 references/cdn-speed-survey.md
   表格列: 域名 | 类型 | HTTP状态 | 耗时(s) | 估算速度(B/s) | Content-Length
   超时记录为 TIMEOUT, 连接失败记为 FAIL
   最后附加分析: 哪些域名是高速通道(>100KB/s), 中速(10-100KB/s), 低速(<10KB/s)

   预计耗时: 12域名 × ~15s = ~3min 执行 + ~7min 整理分析 = 总共 ~10min

5. 持续改进: evolve.sh 完成后，继续主动关闭 polaris-score.md 中的 Milestone 差距
   - 读 polaris-score.md → 找最低分维度 → 尝试关闭下一个 Milestone
   - 每完成一个 Milestone 就 commit 一次
   - 反复循环直到时间用尽或所有 Milestone 被阻塞
6. 记录提交: 更新 evolution-log.md; git add references/; git commit -m "Round N: 摘要"; git push origin worker; bash scripts/release-lock.sh

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
