# OpenCode ↔ oMLX + 必应中文联网搜索

OpenCode 作为客户端，oMLX 作为本地 OpenAI 兼容后端；联网搜索用 **`bing-cn-mcp`**（`cn.bing.com`，免 API Key，墙内可用）。

## 一键配置

```bash
cd /path/to/local-omlx
cp -n .env.example .env   # 如尚未有 .env
./scripts/setup-opencode.sh
./scripts/setup-opencode.sh --check
```

会写入：

1. `~/.config/opencode/opencode.json`（oMLX provider + `bing-cn` MCP）
2. `~/.config/opencode/AGENTS.md`（强制时效问题先搜索）

模板见：[opencode.json.example](opencode.json.example)

## 前置

- oMLX 已启动：`./scripts/start.sh`
- 推荐模型：`Qwen3.5-4B-OptiQ-4bit`（流畅默认）；空机可用 9B
- 已安装 [OpenCode](https://opencode.ai/)：`curl -fsSL https://opencode.ai/install | bash`
- 能访问 `cn.bing.com`（国内一般无需翻墙）

## 环境变量（可选，来自 `.env`）

| 变量 | 默认 | 说明 |
|------|------|------|
| `OMLX_HOST` / `OMLX_PORT` | `127.0.0.1` / `8000` | API 地址 |
| `OMLX_API_KEY` | 与 Admin 一致 | Bearer |
| `OPENCODE_MODEL` | `Qwen3.5-4B-OptiQ-4bit` | 默认模型 id（不含 `omlx/` 前缀） |
| `NPM_REGISTRY` | `https://registry.npmmirror.com` | 国内装 MCP |

## 联网搜索工具

| 工具名 | 作用 |
|--------|------|
| `bing-cn_bing_search` | 必应中文搜索（参数 `query`） |
| `bing-cn_crawl_webpage` | 抓取网页正文 |

提示里可写：`用 bing-cn_bing_search 搜一下 …`

```bash
opencode mcp list   # 应显示 bing-cn connected
```

> 注意：靠爬取页面，过于频繁可能触发必应反爬。知乎 / 公众号等站点可能无法 crawl。

## 模型建议（16GB）

| 场景 | 模型 | 上下文 |
|------|------|--------|
| OpenCode 日常 / Agent | `Qwen3.5-4B-OptiQ-4bit` | 实测可达 128k |
| 空机重答 | `Qwen3.5-9B-OptiQ-4bit` | 实测可达 64k；建议 16k–32k |
| 实验 2bit | `Qwen3.6-35B-A3B-RotorQuant-MLX-2bit` | 约 8k，质量差 |

切换 oMLX 侧模型：`./scripts/switch-model.sh 4b`

## 可选：阿里云百炼 / 博查（更稳，需 Key）

若必应反爬严重，可改用远程 MCP（见阿里云百炼「联网搜索 MCP」文档），或 `@chenpu17/web-bridge-mcp` + 博查 Key。

详见 [OpenCode MCP 文档](https://opencode.ai/docs/mcp-servers/)。
