# Design: download-models.sh 优雅暂停（Ctrl+C）

日期: 2026-07-28  
状态: 已批准交互方案（A），待实现

## 背景

大模型（尤其 35B）下载耗时长，用户需要中途暂停且不丢断点。`hf download` / ModelScope 本身支持续传（`.incomplete`），但脚本缺少对 SIGINT/SIGTERM 的优雅处理；硬杀后常残留 stale `.lock`，阻碍下次续传。另有 `is_downloaded` 判断过松：只要存在任意 `*.safetensors` 即视为完成，会在缺分片时误跳过。

## 目标

1. Ctrl+C（或 SIGTERM）时优雅暂停当前下载，保留断点。
2. 再次运行同一命令即可续传。
3. 修正「已下载」判定，避免缺分片时跳过。

## 非目标

- 不提供独立 `pause` / `resume` 子命令（方案 B）。
- 不改 Windows PowerShell 脚本（除非后续单独立项）。
- 不实现进度 UI / 后台 daemon。

## 方案选择

采用 **trap + 后台子进程**（方案 1）：

| 方案 | 结论 |
|------|------|
| 1. trap + 后台子进程 | **采用**：可可靠 TERM 子进程、等落盘、清 lock |
| 2. 仅 trap + 前台 | 前台时对子进程控制不稳定 |
| 3. `set -m` 进程组 | 非交互 / Cursor 环境下易踩坑 |

## 架构

```
download-models.sh
├── install_pause_trap()     # trap INT TERM → graceful_pause
├── clear_stale_locks(dir)   # 删除 target/.cache 下 *.lock
├── run_download(cmd...)     # 后台执行；记录 PID；wait
├── graceful_pause()         # TERM → 等待 ≤15s → 可选 KILL → 清 lock → exit 130
├── is_downloaded(dir)       # 收紧：config + index 分片齐全（或单文件权重）
├── download_hf_mirror()
└── download_modelscope()
```

## 行为细节

### 暂停

1. 用户 Ctrl+C / 外部 SIGTERM。
2. 打印 `[pause] 正在优雅暂停...`。
3. 向当前下载子进程发 `SIGTERM`。
4. 轮询最多约 15 秒，等待进程退出（便于写完 `.incomplete`）。
5. 仍存活则 `SIGKILL`。
6. `clear_stale_locks` 清理该模型目录下 stale lock。
7. 打印当前目录体积与「再次运行即可续传」提示，以 **exit 130** 退出。

### 启动 / 续传

1. 每个模型下载开始前调用 `clear_stale_locks`，避免上次硬杀卡住。
2. `hf download` / `modelscope download` 通过 `run_download` 在 trap 保护下执行。
3. 正常完成则解除 trap（或仅在该次 wait 结束后继续下一模型）。

### `is_downloaded` 收紧

- 必须有 `config.json`。
- 若存在 `model.safetensors.index.json`：解析 `weight_map`，所有分片文件必须存在于目录中。
- 否则：至少存在一个顶层 `*.safetensors` 或 `model*.safetensors`（兼容无 index 的小模型）。

## 错误处理

- 暂停：固定 exit 130，不触发 `set -e` 的「失败」语义混淆（trap 内直接 `exit`）。
- 下载工具非零退出（网络错误等）：保持现有行为（脚本失败退出），不清空 `.incomplete`。
- lock 清理失败：忽略（`|| true`），不阻断暂停路径。

## 测试计划

1. 启动 `./scripts/download-models.sh hf-mirror 35b`（或较小模型验证流程）。
2. 下载进行中 Ctrl+C → 看到 `[pause]`，进程退出，`.incomplete` 仍在，无残留阻塞性 lock。
3. 再次运行同一命令 → 从断点续传，不从头开始。
4. 故意只保留部分分片 → `is_downloaded` 为假，脚本继续下载缺失分片。
5. 完整模型目录 → 打印「已存在」并跳过。

## 改动文件

- `scripts/download-models.sh`（唯一实现文件）
- 本设计文档

## 成功标准

- Ctrl+C 后可稳定续传，不因 stale lock 卡住。
- 缺分片的半成品不会被误判为已完成。
- usage 中说明 Ctrl+C 可暂停续传。
