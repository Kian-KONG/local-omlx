#!/usr/bin/env bash
# 一键配置：本地模型（oMLX）+ OpenCode（检测缺失则安装/下载）
#
# 用法:
#   ./scripts/bootstrap.sh                 # 默认：16GB 流畅档案（4B）+ OpenCode
#   ./scripts/bootstrap.sh --profile mini16
#   ./scripts/bootstrap.sh --skip-models    # 不下载模型
#   ./scripts/bootstrap.sh --skip-start     # 不启动 oMLX
#   ./scripts/bootstrap.sh --skip-opencode  # 不装/不配 OpenCode
#   ./scripts/bootstrap.sh --proxy URL      # OpenCode 下载走代理（可选翻墙）
#   ./scripts/bootstrap.sh --check          # 只检查状态
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f "$ROOT_DIR/.env" ]]; then
  # shellcheck disable=SC1091
  set -a && source "$ROOT_DIR/.env" && set +a
fi

PROFILE="${BOOTSTRAP_PROFILE:-mini16}"
SOURCE="${OMLX_DOWNLOAD_SOURCE:-hf-mirror}"
SKIP_MODELS=0
SKIP_START=0
SKIP_OPENCODE=0
SKIP_OMLX_INSTALL=0
MODE="run"
PROXY="${OPENCODE_PROXY:-}"
HOST="${OMLX_HOST:-127.0.0.1}"
PORT="${OMLX_PORT:-8000}"
MODEL_DIR="${OMLX_MODEL_DIR:-$HOME/.omlx/models}"

usage() {
  cat <<EOF
用法: $0 [选项]

一键：补 .env → 检测/装 oMLX → 下模型 → 启动服务 → 检测/装 OpenCode → 写配置

  --profile NAME   模型档案: mini16(默认) | 4b | 9b | pro36 | 36-2bit
  --source NAME    hf-mirror（默认）| modelscope
  --proxy URL      仅 OpenCode 安装走代理（翻墙可选）
  --skip-models    跳过模型下载
  --skip-start     跳过启动 oMLX
  --skip-opencode  跳过 OpenCode 安装与配置
  --skip-omlx      跳过 oMLX CLI 安装（已用 DMG 时可加）
  --check          只打印检测结果，不改动

环境变量: OPENCODE_PROXY、OMLX_*、OPENCODE_MODEL、BOOTSTRAP_PROFILE
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help|help) usage; exit 0 ;;
    --profile)
      PROFILE="${2:-}"; [[ -n "$PROFILE" ]] || { echo "--profile 需要值" >&2; exit 1; }
      shift 2
      ;;
    --source)
      SOURCE="${2:-}"; shift 2
      ;;
    --proxy)
      PROXY="${2:-}"; [[ -n "$PROXY" ]] || { echo "--proxy 需要 URL" >&2; exit 1; }
      shift 2
      ;;
    --skip-models) SKIP_MODELS=1; shift ;;
    --skip-start) SKIP_START=1; shift ;;
    --skip-opencode) SKIP_OPENCODE=1; shift ;;
    --skip-omlx) SKIP_OMLX_INSTALL=1; shift ;;
    --check) MODE="check"; shift ;;
    *)
      echo "未知参数: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

step() { echo ""; echo "=== $* ==="; }

have_omlx() {
  command -v omlx >/dev/null 2>&1
}

have_omlx_app() {
  [[ -d "/Applications/oMLX.app" ]] || [[ -d "$HOME/Applications/oMLX.app" ]]
}

api_up() {
  if [[ -n "${OMLX_API_KEY:-}" ]]; then
    curl -fsS -H "Authorization: Bearer ${OMLX_API_KEY}" "http://${HOST}:${PORT}/v1/models" >/dev/null 2>&1
  else
    curl -fsS "http://${HOST}:${PORT}/v1/models" >/dev/null 2>&1
  fi
}

model_dir_nonempty() {
  [[ -d "$MODEL_DIR" ]] && [[ -n "$(ls -A "$MODEL_DIR" 2>/dev/null || true)" ]]
}

have_opencode() {
  local bin="$HOME/.opencode/bin"
  [[ -x "$bin/opencode" ]] && export PATH="$bin:$PATH"
  command -v opencode >/dev/null 2>&1
}

do_check() {
  step "检测"
  echo -n "oMLX CLI:  "; have_omlx && echo "ok ($(command -v omlx))" || echo "缺失"
  echo -n "oMLX App:  "; have_omlx_app && echo "ok" || echo "未检测到 DMG App（可选）"
  echo -n "模型目录:  "; model_dir_nonempty && echo "有内容 ($MODEL_DIR)" || echo "空 ($MODEL_DIR)"
  echo -n "API :$PORT: "; api_up && echo "就绪" || echo "未就绪"
  echo -n "OpenCode:  "
  if have_opencode; then
    echo "ok ($(command -v opencode)) $(opencode --version 2>/dev/null | head -1)"
  else
    echo "缺失（安装可能需翻墙，可用 --proxy）"
  fi
  if [[ -f "$HOME/.config/opencode/opencode.json" ]] || [[ -f "$HOME/.config/opencode/opencode.jsonc" ]]; then
    echo "OpenCode 配置: 已存在"
  else
    echo "OpenCode 配置: 未写入"
  fi
}

if [[ "$MODE" == "check" ]]; then
  do_check
  exit 0
fi

step "环境"
if [[ ! -f "$ROOT_DIR/.env" ]]; then
  cp "$ROOT_DIR/.env.example" "$ROOT_DIR/.env"
  echo "已创建 .env（来自 .env.example）"
else
  echo ".env 已存在"
fi

# profile → 默认 OPENCODE_MODEL（若 .env 未强调，download 仍按 profile）
case "$PROFILE" in
  mini16|both|4b) DEFAULT_OC_MODEL="Qwen3.5-4B-OptiQ-4bit" ;;
  9b) DEFAULT_OC_MODEL="Qwen3.5-9B-OptiQ-4bit" ;;
  pro36|35b) DEFAULT_OC_MODEL="Qwen3.5-35B-A3B-OptiQ-4bit" ;;
  36-2bit|qwen36) DEFAULT_OC_MODEL="Qwen3.6-35B-A3B-RotorQuant-MLX-2bit" ;;
  *) DEFAULT_OC_MODEL="${OPENCODE_MODEL:-Qwen3.5-4B-OptiQ-4bit}" ;;
esac
export OPENCODE_MODEL="${OPENCODE_MODEL:-$DEFAULT_OC_MODEL}"

step "oMLX"
if have_omlx; then
  echo "已安装 CLI: $(command -v omlx)"
elif [[ "$SKIP_OMLX_INSTALL" -eq 1 ]]; then
  echo "跳过 CLI 安装（--skip-omlx）。"
  if have_omlx_app; then
    echo "检测到 oMLX.app — 请在菜单栏 Start Server。"
  else
    echo "未检测到 CLI/App。请先装 DMG 或去掉 --skip-omlx。" >&2
  fi
else
  echo "未找到 omlx CLI，开始安装（也可用 DMG: https://github.com/jundot/omlx/releases）..."
  "$ROOT_DIR/scripts/install-omlx.sh" || {
    echo "brew 安装失败。若已用 DMG: 加 --skip-omlx 并 Start Server 后重试。" >&2
    exit 1
  }
fi

if [[ "$SKIP_MODELS" -eq 0 ]]; then
  step "模型 ($SOURCE / $PROFILE)"
  "$ROOT_DIR/scripts/download-models.sh" "$SOURCE" "$PROFILE"
else
  step "跳过模型下载"
fi

if [[ "$SKIP_START" -eq 0 ]]; then
  step "启动 oMLX"
  if api_up; then
    echo "已在运行: http://${HOST}:${PORT}/v1"
  elif have_omlx; then
    "$ROOT_DIR/scripts/start.sh" || true
    # 若 CLI serve 失败但 App 可能已起
    if ! api_up; then
      echo "CLI 启动后 API 仍未就绪。若使用 oMLX.app，请在菜单栏点 Start Server。" >&2
    fi
  else
    echo "无 omlx CLI，跳过 start.sh。请用 App Start Server。" >&2
  fi
else
  step "跳过启动"
fi

if [[ "$SKIP_OPENCODE" -eq 0 ]]; then
  step "OpenCode"
  install_args=()
  [[ -n "$PROXY" ]] && install_args+=(--proxy "$PROXY")
  if ! "$ROOT_DIR/scripts/install-opencode.sh" "${install_args[@]+"${install_args[@]}"}"; then
    echo "" >&2
    echo "OpenCode 未装成功（常需翻墙）。可稍后:" >&2
    echo "  ./scripts/install-opencode.sh --proxy http://127.0.0.1:7890" >&2
    echo "  或 ./scripts/bootstrap.sh --skip-opencode 后手动安装" >&2
    exit 1
  fi
  # 确保 setup 能找到命令
  [[ -x "$HOME/.opencode/bin/opencode" ]] && export PATH="$HOME/.opencode/bin:$PATH"
  "$ROOT_DIR/scripts/setup-opencode.sh"
else
  step "跳过 OpenCode"
fi

step "完成"
do_check
echo ""
echo "下一步: 重开终端后运行 opencode（或 PATH 含 ~/.opencode/bin）"
echo "  试一句: 用 bing-cn_bing_search 搜一下 xxx"
