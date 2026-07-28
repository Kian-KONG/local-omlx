# Windows RTX 4070 8GB + Qwen3.5-9B

不用 oMLX。用 **Ollama** 提供 OpenAI 兼容 API。

## 安装与下载

```powershell
cd local-omlx\scripts\windows
.\install-ollama.ps1
.\download-models.ps1    # ollama pull qwen3.5:9b
.\status.ps1
```

## 显存

| 量化 | 权重约 | 8GB 4070 |
|------|--------|----------|
| Q4（Ollama 默认 `qwen3.5:9b`） | ~6.6GB | 可用，ctx 建议 ≤8k～16k |
| Q5/Q6 | 更大 | 余量少，不推荐默认 |

## 客户端

- Base URL: `http://127.0.0.1:11434/v1`
- Model: `qwen3.5:9b`
- Key: 任意（如 `ollama`）

详细步骤见 [scripts/windows/README.md](../scripts/windows/README.md)。
