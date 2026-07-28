# Windows RTX 4070（8GB）+ Ollama

Apple Silicon 用仓库根目录的 oMLX 脚本；**本目录仅给 Windows NVIDIA**。

```
CoPaw / Codex  →  http://127.0.0.1:11434/v1  →  Ollama  →  qwen3.5:9b (Q4)
```

## 硬件假设

- GPU: RTX 4070 **8GB**
- 内存: 32GB
- 模型: **Qwen3.5-9B**（Ollama 默认约 Q4，盘约 6–7GB；显存约 7–8GB+KV，ctx 建议先 8k）

8GB 显存跑 9B-Q4 **可以**，但别和大型游戏/Stable Diffusion 抢显存；ctx 开太大易 OOM。

## 一键流程（PowerShell）

```powershell
cd local-omlx\scripts\windows

# 1) 安装 Ollama（若未装）
.\install-ollama.ps1

# 2) 拉取 9B
.\download-models.ps1

# 3) 确认服务与模型
.\status.ps1

# 冒烟
curl.exe http://127.0.0.1:11434/v1/models
```

Ollama 安装后一般会自动在后台跑 API。`start.ps1` / `stop.ps1` 用于启停服务。

## 客户端

| 项 | 值 |
|----|-----|
| Base URL | `http://127.0.0.1:11434/v1` |
| API Key | `ollama`（任意非空即可） |
| Model | `qwen3.5:9b` |

与 Mac 上 oMLX 的 `:8000` **端口不同**，别混用。

## 可选：手动 GGUF（不用 Ollama 拉）

见 `download-gguf.ps1`（hf-mirror → `%USERPROFILE%\models\gguf`），再用 LM Studio / llama-server 加载。日常推荐 Ollama。
