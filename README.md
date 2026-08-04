# local-omlx

多机本地 LLM 工具箱：**Mac 用 oMLX（MLX）**，**Windows 用 Ollama（GGUF）**。仓库只含脚本/文档，不含权重。

```
Mac:     客户端 → :8000/v1  → oMLX  → ~/.omlx/models (OptiQ)
Windows: 客户端 → :11434/v1 → Ollama → qwen3.5:9b
```

## 机型

| 机器 | 路径 | 推荐模型 |
|------|------|----------|
| Mac Mini M4 **16GB** | `scripts/*.sh` | 4B + 9B OptiQ；可选 `36-2bit`（Qwen3.6-35B ~11GB） |
| M3 Pro **36GB** | 同上 | + Qwen3.5-35B-A3B OptiQ-4bit（`pro36`） |
| Windows **4070 8GB** | `scripts/windows/*.ps1` | **Qwen3.5-9B**（`qwen3.5:9b`） |

速查：[configs/machines.md](configs/machines.md) · 16GB 流畅默认：[configs/mac-mini-16gb-fluent.md](configs/mac-mini-16gb-fluent.md) · OpenCode：[configs/opencode.md](configs/opencode.md)

## Mac 快速开始

```bash
git clone git@github.com:Kian-KONG/local-omlx.git
cd local-omlx
cp .env.example .env

# 一键：检测/装 oMLX → 下模型 → 启动 → 检测/装 OpenCode → 写配置
./scripts/bootstrap.sh

# OpenCode 下载若需翻墙（可选）:
# ./scripts/bootstrap.sh --proxy http://127.0.0.1:7890
# 或在 .env 设 OPENCODE_PROXY=http://127.0.0.1:7890

# 也可分步：
# 推荐 DMG 安装 oMLX: https://github.com/jundot/omlx/releases
./scripts/download-models.sh hf-mirror mini16    # 4B + 9B
./scripts/download-models.sh hf-mirror 36-2bit   # Qwen3.6-35B 2bit（16GB）
# 或 pro36 / 35b（36GB+）
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

## 客户端（CoPaw / Codex / OpenCode）

按机器填对应 Base URL + 模型名即可；Mac 与 Windows **端口不同**。

### OpenCode（推荐一键脚本）

```bash
./scripts/bootstrap.sh                 # 模型 + OpenCode 全流程
./scripts/bootstrap.sh --check         # 只检测
./scripts/setup-opencode.sh            # 仅配 OpenCode（缺则自动装）
./scripts/setup-opencode.sh --check
# 可选：把 skills/AGENTS 拷到当前项目 .opencode/
./scripts/setup-opencode.sh --project

# OpenCode 安装需翻墙时（可选）:
./scripts/install-opencode.sh --proxy http://127.0.0.1:7890
# 或: OPENCODE_PROXY=http://127.0.0.1:7890 ./scripts/bootstrap.sh
```

- 对接 oMLX：`http://127.0.0.1:8000/v1`
- 联网搜索：必应中文 MCP（`bing-cn-mcp`）→ `bing-cn_bing_search` / `bing-cn_crawl_webpage`
- 轻量 skills：`local-search`、`local-coding`（适合本地模型，勿装大型 skill 包）
- 文档：[configs/opencode.md](configs/opencode.md) · 模板：[configs/opencode/](configs/opencode/) · JSON：[configs/opencode.json.example](configs/opencode.json.example)

## 脚本一览

| 位置 | 作用 |
|------|------|
| `scripts/bootstrap.sh` | Mac：一键 oMLX + 模型 + OpenCode（代理可选） |
| `scripts/install-opencode.sh` | 检测/安装 OpenCode（`--proxy` 可选翻墙） |
| `scripts/setup-opencode.sh` | Mac：OpenCode → oMLX + bing-cn + 轻量 skills |
| `scripts/install-omlx.sh` 等 | Mac：oMLX（更推荐 DMG） |
| `scripts/windows/*.ps1` | Windows：Ollama + 9B |
