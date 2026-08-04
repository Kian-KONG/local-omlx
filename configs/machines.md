# 机型配置速查

本仓库只放脚本与文档；模型由每台机器自己下载。

## Mac（Apple Silicon → oMLX）

权重目录：`~/.omlx/models`

### Mac Mini M4 16GB

**流畅默认档案**（已实测）：[`mac-mini-16gb-fluent.md`](mac-mini-16gb-fluent.md)  
→ 日常只跑 **`Qwen3.5-4B-OptiQ-4bit`**，上下文实测可达 **128k**。

```bash
./scripts/download-models.sh hf-mirror mini16      # 4B + 9B
./scripts/switch-model.sh 4b                     # 切回流畅默认
./scripts/setup-opencode.sh                      # OpenCode + 必应中文搜索
./scripts/download-models.sh hf-mirror 36-2bit   # 可选：Qwen3.6-35B 2bit
```

| 场景 | 模型 |
|------|------|
| **日常流畅 / OpenCode / CoPaw** | `Qwen3.5-4B-OptiQ-4bit`（默认） |
| 空机调 API（更好质量） | `Qwen3.5-9B-OptiQ-4bit`（实测上下文可达 **64k**；96k 失败） |
| 空机重活（2bit） | `Qwen3.6-35B-A3B-RotorQuant-MLX-2bit` |

切换：`./scripts/switch-model.sh 4b|9b|36-2bit`（同时只加载一个）

> **Qwen3.6-35B 2bit 注意（16GB）**
>
> - 权重约 **11GB**，系统对 memory-guard 的有效上限约 **11.8GB**（≈74% RAM）
> - 需关掉 CoPaw / 其他大模型，并在 `~/.omlx/settings.json` 将 `prefill_memory_guard` 设为 `false`（否则会 `prefill_memory_exceeded`）
> - `.env` 建议：`OMLX_MEMORY_GUARD_GB=14.5`，然后 `./scripts/stop.sh && ./scripts/start.sh`
> - 2bit 质量明显弱于 4bit；短回复可能不稳定，适合「能跑起来」优先的场景
> - 3.6 的 4bit（~20GB）本机跑不动，勿下

### M3 Pro 36GB

```bash
./scripts/download-models.sh hf-mirror pro36
./scripts/download-models.sh hf-mirror 35b   # 只补 35B
```

| 场景 | 模型 |
|------|------|
| 空机重活 | `Qwen3.5-35B-A3B-OptiQ-4bit` |
| CoPaw / Codex | `9B` 或 `4B` |

API: `http://127.0.0.1:8000/v1`

## Windows RTX 4070 8GB（→ Ollama，不用 oMLX）

```powershell
cd local-omlx\scripts\windows
.\install-ollama.ps1
.\download-models.ps1    # hf-mirror 下 GGUF → ollama create（不走 pull）
.\status.ps1
```

| 场景 | 模型 |
|------|------|
| 日常 / CoPaw / Codex | `qwen3.5:9b`（本地 Q4 GGUF 导入） |

API: `http://127.0.0.1:11434/v1`  
国内源：默认走 hf-mirror；需要官方库时用 `.\download-models.ps1 -Pull`。  
详见 [windows-4070.md](windows-4070.md) / [scripts/windows/README.md](../scripts/windows/README.md)
