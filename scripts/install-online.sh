#!/usr/bin/env bash
# 有网络时集中安装 OpenCode，并预热 Bing 中文搜索 MCP。
# setup-opencode.sh 本身保持离线，不会调用本脚本。
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NPM_REGISTRY="${NPM_REGISTRY:-https://registry.npmmirror.com}"
BING_PACKAGE="bing-cn-mcp"
INSTALL_OPENCODE=1
INSTALL_BINGCN=1

usage() {
  cat <<EOF
用法: $0 [选项]

  (无参数)       安装/检查 OpenCode，并用 npx 预热 Bing MCP
  --opencode    只处理 OpenCode
  --bingcn      只处理 Bing MCP
  --proxy URL   传给 OpenCode 安装器
  --help        显示帮助

环境变量: NPM_REGISTRY、OPENCODE_PROXY
EOF
}

PROXY_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --opencode) INSTALL_BINGCN=0; shift ;;
    --bingcn) INSTALL_OPENCODE=0; shift ;;
    --proxy)
      [[ -n "${2:-}" ]] || { echo "--proxy 需要 URL" >&2; exit 1; }
      PROXY_ARGS=(--proxy "$2")
      shift 2
      ;;
    -h|--help|help) usage; exit 0 ;;
    *) echo "未知参数: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ "$INSTALL_OPENCODE" -eq 1 ]]; then
  "$ROOT_DIR/scripts/install-opencode.sh" "${PROXY_ARGS[@]}"
fi

if [[ "$INSTALL_BINGCN" -eq 1 ]]; then
  command -v npx >/dev/null 2>&1 || { echo "缺少 npx，请先安装 Node.js。" >&2; exit 1; }
  echo "预热 ${BING_PACKAGE} (registry=${NPM_REGISTRY})..."
  NPM_CONFIG_REGISTRY="$NPM_REGISTRY" npx -y "$BING_PACKAGE" --help >/dev/null
  echo "Bing MCP 已进入 npx 缓存；配置仍使用 npx -y ${BING_PACKAGE}。"
fi

"$ROOT_DIR/scripts/setup-opencode.sh" --check
