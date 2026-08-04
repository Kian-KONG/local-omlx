#!/usr/bin/env bash
# 检测并安装 OpenCode（官方安装脚本）。下载可能需翻墙，代理为可选。
#
# 用法:
#   ./scripts/install-opencode.sh              # 已安装则跳过；否则官方 curl | bash
#   ./scripts/install-opencode.sh --check      # 只检测，不安装
#   ./scripts/install-opencode.sh --force      # 强制重装/升级
#   ./scripts/install-opencode.sh --proxy URL  # 仅本次安装走代理
#
# 环境变量（可选）:
#   OPENCODE_PROXY / HTTPS_PROXY / HTTP_PROXY / ALL_PROXY  代理 URL
#   OPENCODE_INSTALL=0   禁止自动安装（仅检测；未安装则非 0 退出）
#   OPENCODE_INSTALL_URL 安装脚本地址（默认 https://opencode.ai/install）
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$ROOT_DIR/.env" ]]; then
  # shellcheck disable=SC1091
  set -a && source "$ROOT_DIR/.env" && set +a
fi

MODE="install"
FORCE=0
PROXY="${OPENCODE_PROXY:-}"
INSTALL_URL="${OPENCODE_INSTALL_URL:-https://opencode.ai/install}"
ALLOW_INSTALL="${OPENCODE_INSTALL:-1}"

usage() {
  cat <<EOF
用法: $0 [--check|--force|--proxy URL|--help]

  (无参数)     未安装则下载安装；已安装则跳过
  --check      只检测 PATH 中是否有 opencode
  --force      已安装也再跑官方安装脚本（升级）
  --proxy URL  本次安装使用 HTTP(S) 代理（翻墙可选）

代理也可设环境变量（任选其一）:
  OPENCODE_PROXY / HTTPS_PROXY / HTTP_PROXY / ALL_PROXY

设 OPENCODE_INSTALL=0 时只检测、不安装（未装则退出码 2）。
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help|help) usage; exit 0 ;;
    --check) MODE="check"; shift ;;
    --force) FORCE=1; shift ;;
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

# 官方安装到 ~/.opencode/bin；也可能已在 PATH
ensure_path_hint() {
  local bin="$HOME/.opencode/bin"
  if [[ -x "$bin/opencode" ]] && ! command -v opencode >/dev/null 2>&1; then
    export PATH="$bin:$PATH"
    echo "提示: 已把 $bin 临时加入 PATH；可写入 shell rc，或重开终端。"
  fi
}

opencode_present() {
  ensure_path_hint
  command -v opencode >/dev/null 2>&1
}

print_version() {
  if opencode_present; then
    echo "已找到 opencode: $(command -v opencode)"
    opencode --version 2>/dev/null || true
    return 0
  fi
  echo "未找到 opencode"
  return 1
}

apply_proxy() {
  if [[ -z "$PROXY" ]]; then
    # 沿用已有 HTTPS_PROXY 等
    if [[ -n "${HTTPS_PROXY:-${https_proxy:-${HTTP_PROXY:-${http_proxy:-${ALL_PROXY:-${all_proxy:-}}}}}}" ]]; then
      echo "使用已有代理环境变量进行下载"
    else
      echo "未设置代理（直连）。若下载失败，可: $0 --proxy http://127.0.0.1:7890"
      echo "  或在 .env 设 OPENCODE_PROXY=..."
    fi
    return 0
  fi
  export HTTP_PROXY="$PROXY"
  export HTTPS_PROXY="$PROXY"
  export ALL_PROXY="$PROXY"
  export http_proxy="$PROXY"
  export https_proxy="$PROXY"
  export all_proxy="$PROXY"
  echo "本次安装代理: $PROXY"
}

do_install() {
  need_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
      echo "缺少命令: $1" >&2
      exit 1
    }
  }
  need_cmd curl
  apply_proxy
  echo "运行官方安装: curl -fsSL $INSTALL_URL | bash"
  if ! curl -fsSL "$INSTALL_URL" | bash; then
    echo "" >&2
    echo "OpenCode 安装失败。常见原因：需翻墙访问 GitHub/CDN。" >&2
    echo "  重试: $0 --proxy http://127.0.0.1:端口" >&2
    echo "  或手动: curl -fsSL https://opencode.ai/install | bash" >&2
    exit 1
  fi
  ensure_path_hint
  if ! opencode_present; then
    echo "安装脚本已跑完，但仍找不到 opencode 命令。" >&2
    echo "请检查 $HOME/.opencode/bin 是否在 PATH。" >&2
    exit 1
  fi
  print_version
}

if [[ "$MODE" == "check" ]]; then
  if print_version; then
    exit 0
  fi
  exit 2
fi

if opencode_present && [[ "$FORCE" -eq 0 ]]; then
  print_version
  exit 0
fi

if [[ "$ALLOW_INSTALL" == "0" ]]; then
  echo "OPENCODE_INSTALL=0，跳过安装。" >&2
  print_version || exit 2
  exit 0
fi

do_install
