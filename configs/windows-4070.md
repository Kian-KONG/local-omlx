# Windows RTX 4070 8GB + Qwen3.5-9B

不用 oMLX。用 **Ollama** 提供 OpenAI 兼容 API。

## 安装与下载（推荐：国内源）

```powershell
cd local-omlx\scripts\windows
.\install-ollama.ps1
.\download-models.ps1    # hf-mirror → GGUF → ollama create（写入 ~/.ollama）
.\status.ps1
```

不要手动复制 GGUF 到 `%USERPROFILE%\.ollama\models`。必须用 `ollama create`。

可选官方拉取：`.\download-models.ps1 -Pull`

## 显存

| 量化 | 权重约 | 8GB 4070 |
|------|--------|----------|
| Q4_K_M（默认） | ~6.6GB | 可用，ctx 建议 ≤8k～16k |

## 客户端

- Base URL: `http://127.0.0.1:11434/v1`
- Model: `qwen3.5:9b`
- Key: `ollama`

详见 [scripts/windows/README.md](../scripts/windows/README.md)。
