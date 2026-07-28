# 机型配置速查

本仓库只放脚本与文档；模型由每台机器自己下载到 `~/.omlx/models`。

## Mac Mini M4 16GB

```bash
./scripts/download-models.sh hf-mirror mini16
```

| 场景 | 模型 |
|------|------|
| CoPaw / Codex | `Qwen3.5-4B-OptiQ-4bit` |
| 空机调 API | `Qwen3.5-9B-OptiQ-4bit` |

不要同时 pin 两个 LLM。不跑 35B。

## M3 Pro 36GB

```bash
./scripts/download-models.sh hf-mirror pro36
# 或只补 35B：
./scripts/download-models.sh hf-mirror 35b
```

| 场景 | 模型 |
|------|------|
| 空机推理 / 重活 | `Qwen3.5-35B-A3B-OptiQ-4bit`（~20–26GB） |
| CoPaw / Codex / 多 App | `Qwen3.5-9B-OptiQ-4bit` 或 `4B` |

36GB 跑 35B-A3B **可以**，但和 CoPaw 叠开容易紧，建议卸掉 35B 再开 agent。

## 4070 8G PC（参考）

不用 oMLX（仅 Apple Silicon）。改用 Ollama / llama.cpp + GGUF，仍可把 Base URL 指给 CoPaw/Codex。详见团队另行文档。
