# Mac Mini M4 16GB — 流畅默认档案（已实测）

日常推荐：**只跑 `Qwen3.5-4B-OptiQ-4bit`**，可与 OpenCode / CoPaw 同开。

## 默认模型

| 项 | 值 |
|----|-----|
| 模型 | `Qwen3.5-4B-OptiQ-4bit` |
| HF | `mlx-community/Qwen3.5-4B-OptiQ-4bit` |
| 路径 | `~/.omlx/models/Qwen3.5-4B-OptiQ-4bit` |
| 上下文（实测） | **可达 128k**（needle 检索通过）；日常建议 32k–64k |
| OpenCode | `omlx/Qwen3.5-4B-OptiQ-4bit` + 必应中文 `bing-cn` MCP |

## `.env`（流畅默认）

```bash
OMLX_MEMORY_GUARD_GB=10
OMLX_MAX_PROCESS_MEMORY=12GB
OMLX_MAX_MODEL_MEMORY=10GB
OMLX_MAX_CONCURRENT_REQUESTS=2
OPENCODE_MODEL=Qwen3.5-4B-OptiQ-4bit
```

应用：

```bash
./scripts/stop.sh && ./scripts/start.sh
./scripts/switch-model.sh 4b
./scripts/setup-opencode.sh   # 如尚未配置
```

## 切换到其他模型时

| 模型 | 何时用 | 上下文（实测） | 内存注意 |
|------|--------|----------------|----------|
| `Qwen3.5-9B-OptiQ-4bit` | 空机、要更好质量 | **可达 64k**；**96k 失败**；日常建议 16k–32k | 先 Unload 4B；少开 CoPaw |
| `Qwen3.6-35B-A3B-RotorQuant-MLX-2bit` | 实验 | 约 **8k**；16k+ OOM | 抬高 guard / 关 prefill guard |

切回流畅默认：`./scripts/switch-model.sh 4b`

### 9B 上下文阶梯（空机、OptiQ-4bit）

| 上下文 | prompt tokens | 耗时 | 结果 |
|--------|---------------|------|------|
| 8k | 7,840 | ~36s | 通过 |
| 16k | 15,811 | ~71s | 通过 |
| 32k | 31,761 | ~160s | 通过 |
| 48k | 47,711 | ~251s | 通过 |
| **64k** | **63,652** | ~360s | **通过** |
| 96k | — | ~452s | **失败**（连接中断 / 疑似 OOM） |

### 4B 上下文阶梯（空机、OptiQ-4bit）

| 上下文 | 结果 |
|--------|------|
| 32k / 48k / 64k / 96k / **128k** | 全部 needle 通过 |

## 经验沉淀（16GB）

1. **日常默认只用 4B**：OpenCode / CoPaw 同开最稳；要质量再空机切 9B。
2. **同时只加载一个大模型**：`./scripts/switch-model.sh 4b|9b|36-2bit`。
3. **联网搜索用必应中文**：`bing-cn-mcp`（`cn.bing.com`），墙内免 Key；DuckDuckGo 常空结果，勿默认。
4. **小模型常跳过工具**：时效问题要明示「先 `bing-cn_bing_search`」；`AGENTS.md` + 轻量 skills（`local-search` / `local-coding`）+ `tools: true` 已写入 setup 脚本。勿装大型 skill 合集。
5. **Qwen3.6 2bit 仅实验**：约 8k 上下文，需抬高 memory guard / 关 `prefill_memory_guard`；质量远弱于 4bit。
6. **勿下 3.6 的 4bit（~20GB）**：16GB 跑不动。

一键 OpenCode：`./scripts/setup-opencode.sh`（详见 [opencode.md](opencode.md)）

