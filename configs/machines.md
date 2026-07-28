# 机型配置速查

本仓库只放脚本与文档；模型由每台机器自己下载。

## Mac（Apple Silicon → oMLX）

权重目录：`~/.omlx/models`

### Mac Mini M4 16GB

```bash
./scripts/download-models.sh hf-mirror mini16
```

| 场景 | 模型 |
|------|------|
| CoPaw / Codex | `Qwen3.5-4B-OptiQ-4bit` |
| 空机调 API | `Qwen3.5-9B-OptiQ-4bit` |

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
