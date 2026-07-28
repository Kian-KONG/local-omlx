# Windows RTX 4070（8GB）+ Ollama

Apple Silicon 用仓库根目录的 oMLX 脚本；**本目录仅给 Windows NVIDIA**。

```
CoPaw / Codex  →  http://127.0.0.1:11434/v1  →  Ollama  →  qwen3.5:9b (Q4)
```

## 硬件假设

- GPU: RTX 4070 **8GB**
- 内存: 32GB
- 模型: **Qwen3.5-9B** Q4_K_M（约 6–7GB；ctx 建议先 8k）

## 推荐流程（国内源下 GGUF → 导入 Ollama，不走 pull）

```powershell
cd local-omlx\scripts\windows
.\install-ollama.ps1
.\download-models.ps1          # hf-mirror 下 GGUF + ollama create
.\status.ps1
```

原理：

1. 从 `hf-mirror` 下载 `Qwen3.5-9B-Q4_K_M.gguf` → `%USERPROFILE%\models\gguf`
2. `ollama create qwen3.5:9b -f Modelfile`（`FROM` 指向本地 GGUF）
3. Ollama **自己**把 blob 写进 `%USERPROFILE%\.ollama\models`

**不要**手动把 GGUF 复制进 `.ollama\models`，格式对不上。

若代理很好、想直接官方拉：

```powershell
.\download-models.ps1 -Pull
```

## 客户端

| 项 | 值 |
|----|-----|
| Base URL | `http://127.0.0.1:11434/v1` |
| API Key | `ollama` |
| Model | `qwen3.5:9b` |

与 Mac oMLX 的 `:8000` 不同，别混用。

## 其它脚本

| 脚本 | 作用 |
|------|------|
| `start.ps1` / `stop.ps1` | 启停 Ollama |
| `status.ps1` | 检查 API / 模型列表 |
| `download-gguf.ps1` | 只下 GGUF、不导入 Ollama（给 LM Studio 等） |
