# local-omlx

多机本地 LLM 工具箱：**Mac 用 oMLX（MLX）**，**Windows 用 Ollama（GGUF）**。仓库只含脚本/文档，不含权重。

```
Mac:     客户端 → :8000/v1  → oMLX  → ~/.omlx/models (OptiQ)
Windows: 客户端 → :11434/v1 → Ollama → qwen3.5:9b
```

## 机型

| 机器 | 路径 | 推荐模型 |
|------|------|----------|
| Mac Mini M4 **16GB** | `scripts/*.sh` | 4B + 9B OptiQ（`mini16`） |
| M3 Pro **36GB** | 同上 | + 35B-A3B（`pro36`） |
| Windows **4070 8GB** | `scripts/windows/*.ps1` | **Qwen3.5-9B**（`qwen3.5:9b`） |

速查：[configs/machines.md](configs/machines.md)

## Mac 快速开始

```bash
git clone git@github.com:Kian-KONG/local-omlx.git
cd local-omlx
cp .env.example .env

# 推荐 DMG 安装 oMLX: https://github.com/jundot/omlx/releases
./scripts/download-models.sh hf-mirror mini16   # 或 pro36 / 35b
```

API: `http://127.0.0.1:8000/v1`（Key 与 oMLX Admin 一致）

## Windows 4070 快速开始

```powershell
git clone git@github.com:Kian-KONG/local-omlx.git
cd local-omlx\scripts\windows
.\install-ollama.ps1
.\download-models.ps1    # 国内 hf-mirror 下 GGUF，再 ollama create（不 pull）
.\status.ps1
```

API: `http://127.0.0.1:11434/v1`  
Model: `qwen3.5:9b`  
Key: `ollama`

详见 [scripts/windows/README.md](scripts/windows/README.md)、[configs/windows-4070.md](configs/windows-4070.md)

## 客户端（CoPaw / Codex）

按机器填对应 Base URL + 模型名即可；Mac 与 Windows **端口不同**。

## 脚本一览

| 位置 | 作用 |
|------|------|
| `scripts/download-models.sh` | Mac：hf-mirror 下 OptiQ |
| `scripts/install-omlx.sh` 等 | Mac：oMLX（更推荐 DMG） |
| `scripts/windows/*.ps1` | Windows：Ollama + 9B |
