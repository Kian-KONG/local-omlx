# local-omlx

多机复用的 **oMLX 模型下载 / 使用说明**仓库。权重默认进 `~/.omlx/models`（与 oMLX DMG 一致）；也可在 oMLX Admin 里自行下载。

```
CoPaw / Codex / 其他  →  http://127.0.0.1:8000/v1  →  oMLX  →  ~/.omlx/models/*
```

不提交模型文件、不提交 `.env`（含 API Key）。

## 机型怎么选模型

| 机器 | 推荐下载 | 日常 / Agent | 升档 |
|------|----------|--------------|------|
| Mac Mini M4 **16GB** | `mini16`（4B+9B） | CoPaw/Codex → **4B** | 空机 API → **9B** |
| M3 Pro **36GB** | `pro36`（4B+9B+35B-A3B） | Agent → **9B**；空机 → **35B-A3B** | 同时开很多 App 时退回 9B/4B |

**M3 Pro 36GB 可以跑 `Qwen3.5-35B-A3B-OptiQ-4bit`**：盘约 20–21GB，推理大约 20–26GB，36GB 够用但余量有限——跑 35B 时尽量少开 Chrome/Docker/CoPaw；开 CoPaw 时仍建议 9B 或 4B。

## 快速开始（任意 Mac）

```bash
git clone <你的远程>/local-omlx.git
cd local-omlx
cp .env.example .env   # 按机型改内存相关变量

# 1) 装 oMLX：推荐 DMG（免 brew 源码编译）
#    https://github.com/jundot/omlx/releases
#    或: ./scripts/install-omlx.sh

# 2) 下载模型（也可只用 oMLX Admin 下载）
./scripts/download-models.sh hf-mirror mini16   # 16GB
./scripts/download-models.sh hf-mirror pro36    # 36GB+
./scripts/download-models.sh hf-mirror 35b      # 只下 35B

# 3) 确认 oMLX model_dir = ~/.omlx/models，重启服务后:
curl -s -H "Authorization: Bearer $OMLX_API_KEY" http://127.0.0.1:8000/v1/models
```

| 命令 | 内容 |
|------|------|
| `mini16` / `both` | 4B + 9B |
| `pro36` | 4B + 9B + 35B-A3B |
| `4b` / `9b` / `35b` | 单个 |

## 目录约定

```
~/.omlx/models/
  Qwen3.5-4B-OptiQ-4bit/
  Qwen3.5-9B-OptiQ-4bit/
  Qwen3.5-35B-A3B-OptiQ-4bit/   # 仅 36GB+ 建议
~/.omlx/settings.json
```

## 客户端

- CoPaw：见 [configs/copaw-provider.md](configs/copaw-provider.md)
- Codex / 其他 OpenAI 兼容：Base URL `http://127.0.0.1:8000/v1`，Key 与 oMLX Admin 一致

## 脚本

| 脚本 | 作用 |
|------|------|
| `scripts/download-models.sh` | hf-mirror / modelscope 下载 OptiQ |
| `scripts/install-omlx.sh` | brew 安装（更推荐 DMG） |
| `scripts/start.sh` / `stop.sh` | CLI 启停（DMG 用户可用菜单栏） |
| `scripts/switch-model.sh` | 列出模型 / 切换提示 |

## 36GB `.env` 提示

```bash
# 复制后可按机型调整
OMLX_MEMORY_GUARD_GB=28
OMLX_MAX_PROCESS_MEMORY=30GB
OMLX_MAX_MODEL_MEMORY=26GB
```

16GB 保持 example 里更保守的 10/12/10 即可。
