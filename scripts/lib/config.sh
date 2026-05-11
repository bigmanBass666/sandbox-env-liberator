#!/bin/bash
# lib/config.sh — 共享超时常量和全局配置
# 来源: PR #7 提案 P2 项

set -euo pipefail

# 网络超时（秒）
readonly NETWORK_TIMEOUT_SHORT=5      # 快速探测（DNS、端口检查）
readonly NETWORK_TIMEOUT_MEDIUM=10     # 标准请求（HTTP API、文件下载）
readonly NETWORK_TIMEOUT_LONG=30       # 大文件下载、复杂操作

# Phase 全局超时（秒）
readonly PHASE_TIMEOUT=120             # evolve.sh 单轮最大运行时间

# 进程超时（秒）
readonly PROCESS_TIMEOUT=30             # 服务启动等待时间
