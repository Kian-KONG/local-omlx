# OpenCode ↔ oMLX + 必应中文联网搜索 + 本地轻量 skills

OpenCode 作为客户端，oMLX 作为本地 OpenAI 兼容后端；联网搜索用 **`bing-cn-mcp`**（`cn.bing.com`，免 API Key，墙内可用）。

## 一键配置

```bash
cd /path/to/local-omlx
cp -n .env.example .env   # 如尚未有 .env

# 推荐：模型 + OpenCode 全流程
./scripts/bootstrap.sh
./scripts/bootstrap.sh --check

# OpenCode 二进制下载若需翻墙（可选，不设则直连）:
./scripts/bootstrap.sh --proxy http://127.0.0.1:7890
# 或在 .env: OPENCODE_PROXY=http://127.0.0.1:7890

# 仅配置 OpenCode（缺则自动装）
./scripts/setup-opencode.sh
./scripts/setup-opencode.sh --check
```

会写入全局 `~/.config/opencode/`：

1. `opencode.json`（oMLX provider + `bing-cn` MCP）
2. `AGENTS.md`（强制时效问题先搜索）
3. `skills/local-search`、`skills/local-coding`（轻量、按需加载）
4. `agent/local.md`（本地模型 agent，工具全开）

模板源目录：[opencode/](opencode/) · JSON 示例：[opencode.json.example](opencode.json.example)

### OpenCode 安装与代理

| 命令 | 说明 |
|------|------|
| `./scripts/install-opencode.sh` | 已装则跳过；未装则官方脚本安装 |
| `./scripts/install-opencode.sh --check` | 只检测 |
| `./scripts/install-opencode.sh --proxy URL` | 本次安装走代理 |
| `OPENCODE_INSTALL=0` | 禁止自动安装 |

代理也可用系统已有的 `HTTPS_PROXY` / `HTTP_PROXY` / `ALL_PROXY`。直连失败时再开代理即可，**不是必选**。

### 给某个项目单独复用

在目标仓库根目录执行（skills / AGENTS 写入该仓 `.opencode/`）：

```bash
cd /path/to/your-project
/path/to/local-omlx/scripts/setup-opencode.sh --project
```

或手动拷贝：

```bash
mkdir -p .opencode
cp -R /path/to/local-omlx/configs/opencode/skills .opencode/
cp /path/to/local-omlx/configs/opencode/AGENTS.md .opencode/
```

全局配置仍负责 provider / MCP；项目 skills 会与全局 skills 一并被 OpenCode 发现。

## 前置

- oMLX 已启动：`./scripts/start.sh`（或 `./scripts/bootstrap.sh`）
- 推荐模型：`Qwen3.5-4B-OptiQ-4bit`（流畅默认）；空机可用 9B
- OpenCode：脚本会检测，缺失则安装；也可手动 `./scripts/install-opencode.sh`
- 能访问 `cn.bing.com`（搜索 MCP，国内一般无需翻墙）；**安装 OpenCode 二进制**若失败再开可选代理

## 环境变量（可选，来自 `.env`）

| 变量 | 默认 | 说明 |
|------|------|------|
| `OMLX_HOST` / `OMLX_PORT` | `127.0.0.1` / `8000` | API 地址 |
| `OMLX_API_KEY` | 与 Admin 一致 | Bearer |
| `OPENCODE_MODEL` | `Qwen3.5-4B-OptiQ-4bit` | 默认模型 id（不含 `omlx/` 前缀） |
| `NPM_REGISTRY` | `https://registry.npmmirror.com` | 国内装 MCP |
| `OPENCODE_PROXY` | （空） | 仅安装 OpenCode 时可选代理 |
| `OPENCODE_INSTALL` | `1` | 设 `0` 禁止自动安装 OpenCode |

## 联网搜索工具

| 工具名 | 作用 |
|--------|------|
| `bing-cn_bing_search` | 必应中文搜索（参数 `query`） |
| `bing-cn_crawl_webpage` | 抓取网页正文 |

提示里可写：`用 bing-cn_bing_search 搜一下 …`

```bash
opencode mcp list   # 应显示 bing-cn connected
opencode debug skill  # 应含 local-search / local-coding
```

> 注意：靠爬取页面，过于频繁可能触发必应反爬。知乎 / 公众号等站点可能无法 crawl。

## 轻量 skills（适合本地模型）

| Skill | 何时用 |
|-------|--------|
| `local-search` | 时效 / 版本 / 文档 → 强制走 bing-cn |
| `local-coding` | 改代码 → grep 先、小 diff、少读文件 |

**不要**装大型 skill 合集（superpowers、上千条 catalog）：描述列表会撑爆本地模型 prefill。

## 模型建议（16GB）

| 场景 | 模型 | 上下文 |
|------|------|--------|
| OpenCode 日常 / Agent | `Qwen3.5-4B-OptiQ-4bit` | 实测可达 128k |
| 空机重答 | `Qwen3.5-9B-OptiQ-4bit` | 实测可达 64k；建议 16k–32k |
| 实验 2bit | `Qwen3.6-35B-A3B-RotorQuant-MLX-2bit` | 约 8k，质量差 |

切换 oMLX 侧模型：`./scripts/switch-model.sh 4b`

## Windows（Ollama）

模板：[opencode-windows.json.example](opencode-windows.json.example)（`qwen3.5:9b` + bing-cn）。skills / AGENTS 仍可从 `configs/opencode/` 拷到 Windows 的 OpenCode 配置目录。

## 可选：阿里云百炼 / 博查（更稳，需 Key）

若必应反爬严重，可改用远程 MCP（见阿里云百炼「联网搜索 MCP」文档），或 `@chenpu17/web-bridge-mcp` + 博查 Key。

详见 [OpenCode MCP 文档](https://opencode.ai/docs/mcp-servers/)。
