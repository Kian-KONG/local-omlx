#!/usr/bin/env bash
# 配置 OpenCode → oMLX，并接入必应中文联网搜索 MCP + 本地轻量 skills
#
# 用法:
#   ./scripts/setup-opencode.sh              # 离线写入 OpenCode 配置和本地 skills
#   ./scripts/setup-opencode.sh --check      # 只检查 MCP / skills 状态
#   ./scripts/setup-opencode.sh --dry-run    # 打印将写入的配置，不落盘
#   ./scripts/setup-opencode.sh --project    # 额外把 skills/AGENTS 拷到当前目录 .opencode/
#   ./scripts/setup-opencode.sh --skip-install  # 兼容旧参数（当前始终不下载）
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
TEMPLATE_DIR="$ROOT_DIR/configs/opencode"
MODE=""
INSTALL_PROJECT=0
SKIP_INSTALL=0
PROXY="${OPENCODE_PROXY:-}"

usage() {
  cat <<EOF
用法: $0 [选项]

  (无参数)         离线写入全局 ~/.config/opencode
  --check          检查 opencode / MCP / skills
  --dry-run        打印配置 JSON，不写入
  --project        同时把 skills + AGENTS 拷到 \$PWD/.opencode/
  --proxy URL      兼容旧参数；不再触发下载
  --skip-install   兼容旧参数；setup 当前始终不下载

环境变量: OMLX_HOST OMLX_PORT OMLX_API_KEY OPENCODE_MODEL NPM_REGISTRY OPENCODE_PROXY
默认模型: $DEFAULT_MODEL
目标文件: $OPENCODE_JSON
模板目录: $TEMPLATE_DIR
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help|help) usage; exit 0 ;;
    --check) MODE="check"; shift ;;
    --dry-run) MODE="dry-run"; shift ;;
    --project) INSTALL_PROJECT=1; shift ;;
    --skip-install) SKIP_INSTALL=1; shift ;;
    --proxy)
      [[ -n "${2:-}" ]] || { echo "--proxy 需要 URL" >&2; exit 1; }
      PROXY="$2"
      shift 2
      ;;
    *)
      echo "未知参数: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "缺少命令: $1" >&2
    exit 1
  }
}

ensure_opencode_path() {
  local bin="$HOME/.opencode/bin"
  if [[ -x "$bin/opencode" ]] && ! command -v opencode >/dev/null 2>&1; then
    export PATH="$bin:$PATH"
  fi
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
if "ddg" in mcp and isinstance(mcp["ddg"], dict):
    mcp["ddg"]["enabled"] = False
bing = mcp.setdefault("bing-cn", {})
bing["type"] = "local"
bing["command"] = ["npx", "-y", "bing-cn-mcp"]
bing["enabled"] = True
bing["timeout"] = 45000
bing.setdefault("environment", {})["NPM_CONFIG_REGISTRY"] = npm_registry
cfg["instructions"] = [
    "For current events, versions, prices, docs, or anything that may be outside training data: "
    "you MUST call tool bing-cn_bing_search first (argument: query). Do not answer from memory alone. "
    "To read a page, call bing-cn_crawl_webpage. Cite URLs from tool results. Prefer bing-cn over other search tools."
]
print(json.dumps(cfg, indent=2, ensure_ascii=False))
PY
}

install_templates() {
  local dest="$1"
  mkdir -p "$dest/skills" "$dest/agent"
  cp "$TEMPLATE_DIR/AGENTS.md" "$dest/AGENTS.md"
  for skill in local-search local-coding local-verify; do
    mkdir -p "$dest/skills/$skill"
    cp "$TEMPLATE_DIR/skills/$skill/SKILL.md" "$dest/skills/$skill/SKILL.md"
  done
  sed "s/__OPENCODE_MODEL__/${DEFAULT_MODEL}/g" \
    "$TEMPLATE_DIR/agent/local.md.example" >"$dest/agent/local.md"
}

do_check() {
  echo "=== OpenCode ==="
  ensure_opencode_path
  if command -v opencode >/dev/null 2>&1; then
    opencode --version 2>/dev/null || true
  else
    echo "未找到 opencode（可: ./scripts/install-opencode.sh [--proxy URL]）" >&2
  fi
  echo ""
  echo "=== Bing MCP（仅本地配置，不联网检查） ==="
  echo "包: bing-cn-mcp"
  echo "安装: ./scripts/install-online.sh --bingcn"
  echo ""
  echo "=== MCP list ==="
  if command -v opencode >/dev/null 2>&1; then
    opencode mcp list 2>&1 || true
  fi
  echo ""
  echo "=== Skills ==="
  if command -v opencode >/dev/null 2>&1; then
    opencode debug skill 2>&1 | python3 -c 'import sys,json; d=json.load(sys.stdin); print([x.get("name") for x in d])' 2>/dev/null || true
  fi
  echo ""
  echo "配置文件: $OPENCODE_JSON"
  [[ -f "$OPENCODE_JSON" ]] && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print("model=",d.get("model")); print("mcp=",list((d.get("mcp") or {}).keys()))' "$OPENCODE_JSON"
  echo "AGENTS: $OPENCODE_DIR/AGENTS.md"
  echo "skills: $OPENCODE_DIR/skills/"
}

if [[ "$MODE" == "check" ]]; then
  do_check
  exit 0
fi

need_cmd python3
[[ -f "$EXAMPLE" ]] || { echo "缺少模板: $EXAMPLE" >&2; exit 1; }
[[ -d "$TEMPLATE_DIR/skills" ]] || { echo "缺少模板目录: $TEMPLATE_DIR" >&2; exit 1; }

CFG_JSON="$(build_config)"

if [[ "$MODE" == "dry-run" ]]; then
  echo "$CFG_JSON"
  echo ""
  echo "# would also install:"
  echo "#   $OPENCODE_DIR/AGENTS.md"
  echo "#   $OPENCODE_DIR/skills/{local-search,local-coding,local-verify}/SKILL.md"
  echo "#   $OPENCODE_DIR/agent/local.md  (model=omlx/$DEFAULT_MODEL)"
  exit 0
fi

mkdir -p "$OPENCODE_DIR"
if [[ -f "$OPENCODE_JSON" ]]; then
  cp "$OPENCODE_JSON" "${OPENCODE_JSON}.bak.$(date +%Y%m%d%H%M%S)"
  echo "已备份原配置 → ${OPENCODE_JSON}.bak.*"
fi
printf '%s\n' "$CFG_JSON" >"$OPENCODE_JSON"

install_templates "$OPENCODE_DIR"

if [[ "$INSTALL_PROJECT" -eq 1 ]]; then
  PROJECT_OC="$PWD/.opencode"
  install_templates "$PROJECT_OC"
  echo "已写入项目: $PROJECT_OC"
fi

echo "已写入: $OPENCODE_JSON"
echo "  baseURL: $BASE_URL"
echo "  model:   omlx/$DEFAULT_MODEL"
echo "  mcp:     bing-cn → npx -y bing-cn-mcp（需另行安装）"
echo "  agents:  $OPENCODE_DIR/AGENTS.md"
echo "  skills:  local-search, local-coding, local-verify"
echo "  agent:   $OPENCODE_DIR/agent/local.md"
echo ""
echo "验证:"
echo "  opencode mcp list"
echo "  opencode debug skill"
echo "  Bing MCP 安装后再验证: 用 bing-cn_bing_search 搜一下 xxx"
do_check || true
