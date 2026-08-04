#!/usr/bin/env bash
# 配置 OpenCode → oMLX，并接入必应中文联网搜索 MCP（bing-cn-mcp，免 API Key，墙内可用）
#
# 用法:
#   ./scripts/setup-opencode.sh           # 写入 ~/.config/opencode/opencode.json
#   ./scripts/setup-opencode.sh --check   # 只检查 MCP 状态
#   ./scripts/setup-opencode.sh --dry-run # 打印将写入的配置，不落盘
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$ROOT_DIR/.env" ]]; then
  # shellcheck disable=SC1091
  set -a && source "$ROOT_DIR/.env" && set +a
fi

HOST="${OMLX_HOST:-127.0.0.1}"
PORT="${OMLX_PORT:-8000}"
API_KEY="${OMLX_API_KEY:-123qwe}"
BASE_URL="http://${HOST}:${PORT}/v1"
DEFAULT_MODEL="${OPENCODE_MODEL:-Qwen3.5-4B-OptiQ-4bit}"
NPM_REGISTRY="${NPM_REGISTRY:-https://registry.npmmirror.com}"
OPENCODE_DIR="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
OPENCODE_JSON="$OPENCODE_DIR/opencode.json"
EXAMPLE="$ROOT_DIR/configs/opencode.json.example"
MODE="${1:-}"

usage() {
  cat <<EOF
用法: $0 [--check|--dry-run|--help]

  (无参数)   写入 OpenCode 配置（oMLX + bing-cn-mcp 必应中文搜索）
  --check    检查 opencode / MCP 是否可用
  --dry-run  打印配置 JSON，不写入

环境变量: OMLX_HOST OMLX_PORT OMLX_API_KEY OPENCODE_MODEL NPM_REGISTRY
默认模型: $DEFAULT_MODEL
目标文件: $OPENCODE_JSON
EOF
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "缺少命令: $1" >&2
    exit 1
  }
}

build_config() {
  python3 - "$EXAMPLE" "$BASE_URL" "$API_KEY" "$DEFAULT_MODEL" "$NPM_REGISTRY" <<'PY'
import json, sys
example_path, base_url, api_key, default_model, npm_registry = sys.argv[1:6]
cfg = json.load(open(example_path))
cfg["model"] = f"omlx/{default_model}"
prov = cfg.setdefault("provider", {}).setdefault("omlx", {})
opts = prov.setdefault("options", {})
opts["baseURL"] = base_url
opts["apiKey"] = api_key
models = prov.setdefault("models", {})
if default_model not in models:
    models[default_model] = {
        "name": default_model,
        "modalities": {"input": ["text"], "output": ["text"]},
        "limit": {"context": 131072, "output": 8192},
        "tools": True,
    }
for m in models.values():
    m["tools"] = True
mcp = cfg.setdefault("mcp", {})
# drop legacy DDG server if present in merged configs
mcp.pop("web-search", None)
bing = mcp.setdefault("bing-cn", {})
bing["type"] = "local"
bing["command"] = ["npx", "-y", "bing-cn-mcp"]
bing["enabled"] = True
bing["timeout"] = 45000
bing.setdefault("environment", {})["NPM_CONFIG_REGISTRY"] = npm_registry
cfg["instructions"] = [
    "For current events, versions, prices, docs, or anything that may be outside training data: "
    "you MUST call tool bing-cn_bing_search first (argument: query). Do not answer from memory alone. "
    "To read a page, call bing-cn_crawl_webpage. Cite URLs from tool results."
]
print(json.dumps(cfg, indent=2, ensure_ascii=False))
PY
}

do_check() {
  echo "=== OpenCode ==="
  if command -v opencode >/dev/null 2>&1; then
    opencode --version 2>/dev/null || true
  else
    echo "未找到 opencode（可: curl -fsSL https://opencode.ai/install | bash）" >&2
  fi
  echo ""
  echo "=== npx / bing-cn-mcp ==="
  need_cmd npx
  # 包存在即可；直接跑二进制会挂在 stdio 等待 MCP 客户端
  NPM_CONFIG_REGISTRY="$NPM_REGISTRY" npm view bing-cn-mcp version name 2>&1 | head -5 || true
  echo ""
  echo "=== MCP list ==="
  if command -v opencode >/dev/null 2>&1; then
    opencode mcp list 2>&1 || true
  fi
  echo ""
  echo "配置文件: $OPENCODE_JSON"
  [[ -f "$OPENCODE_JSON" ]] && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print("model=",d.get("model")); print("mcp=",list((d.get("mcp") or {}).keys()))' "$OPENCODE_JSON"
}

case "$MODE" in
  -h|--help|help) usage; exit 0 ;;
  --check) do_check; exit 0 ;;
esac

need_cmd python3
need_cmd npx
[[ -f "$EXAMPLE" ]] || { echo "缺少模板: $EXAMPLE" >&2; exit 1; }

# 预热 npm 缓存（国内镜像）
if [[ "$MODE" != "--dry-run" ]]; then
  echo "预取 bing-cn-mcp（registry=$NPM_REGISTRY）..."
  NPM_CONFIG_REGISTRY="$NPM_REGISTRY" npm pack bing-cn-mcp --silent >/dev/null 2>&1 || \
    NPM_CONFIG_REGISTRY="$NPM_REGISTRY" npx -y bing-cn-mcp --help >/dev/null 2>&1 || true
fi

CFG_JSON="$(build_config)"

if [[ "$MODE" == "--dry-run" ]]; then
  echo "$CFG_JSON"
  exit 0
fi

mkdir -p "$OPENCODE_DIR"
if [[ -f "$OPENCODE_JSON" ]]; then
  cp "$OPENCODE_JSON" "${OPENCODE_JSON}.bak.$(date +%Y%m%d%H%M%S)"
  echo "已备份原配置 → ${OPENCODE_JSON}.bak.*"
fi
printf '%s\n' "$CFG_JSON" >"$OPENCODE_JSON"

# AGENTS.md 强化小模型工具调用
cat >"$OPENCODE_DIR/AGENTS.md" <<'EOF'
# 联网搜索（必应中文 MCP）

涉及时效、版本号、新闻、价格、文档更新时：

1. **先**调用 `bing-cn_bing_search`（参数 `query`），禁止只用训练记忆作答。
2. 需要正文时再调用 `bing-cn_crawl_webpage`。
3. 回答里引用工具返回的 URL；工具无结果时说明「搜索无结果」，不要编造。
EOF

echo "已写入: $OPENCODE_JSON"
echo "  baseURL: $BASE_URL"
echo "  model:   omlx/$DEFAULT_MODEL"
echo "  mcp:     bing-cn → npx -y bing-cn-mcp"
echo "  agents:  $OPENCODE_DIR/AGENTS.md"
echo ""
echo "验证:"
echo "  opencode mcp list"
echo "  在 OpenCode 里问: 用 bing-cn_bing_search 搜一下 xxx"
do_check || true
