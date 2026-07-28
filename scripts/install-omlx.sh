#!/usr/bin/env bash
# 安装 oMLX（Homebrew 稳定版优先）
#
# 重要：jundot/omlx formula 会强制
#   pip install --no-binary cohere_melody,pydantic-core,rpds-py,tiktoken
# 并 git 拉取 mlx-lm。这不是卡死，首次常要 20–40+ 分钟。
# 若长时间停在 GitHub fetch：检查代理，或改下官方 DMG（免编译）。
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$ROOT_DIR/.env" ]]; then
  # shellcheck disable=SC1091
  set -a && source "$ROOT_DIR/.env" && set +a
fi

# 默认 0：装 stable。设 1 会额外编 custom kernel，更慢且需完整 Xcode。
WITH_KERNEL="${OMLX_WITH_CUSTOM_KERNEL:-0}"
PIP_INDEX_URL="${PIP_INDEX_URL:-https://pypi.tuna.tsinghua.edu.cn/simple}"

if ! command -v brew >/dev/null 2>&1; then
  echo "需要 Homebrew。请先安装: https://brew.sh" >&2
  exit 1
fi

uname_m="$(uname -m)"
if [[ "$uname_m" != "arm64" ]]; then
  echo "oMLX 仅支持 Apple Silicon，当前: $uname_m" >&2
  exit 1
fi

sw_vers_product="$(sw_vers -productVersion 2>/dev/null || true)"
echo "检测到 macOS $sw_vers_product / $uname_m"
echo "oMLX 要求 macOS 15.0+ (Sequoia)"
echo ""
echo "说明: brew 安装会源码编译 pydantic-core 等，并 git clone mlx-lm。"
echo "      停在 --no-binary ... 一行时请耐心等待；真正卡住多半是访问 GitHub。"
echo "      替代方案（免编译）: https://github.com/jundot/omlx/releases 下载 DMG"
echo ""

if ! brew tap | grep -q '^jundot/omlx$'; then
  echo "添加 tap: jundot/omlx ..."
  brew tap jundot/omlx https://github.com/jundot/omlx
fi

export HOMEBREW_NO_AUTO_UPDATE="${HOMEBREW_NO_AUTO_UPDATE:-1}"
export PIP_INDEX_URL
export HOMEBREW_PIP_INDEX_URL="${HOMEBREW_PIP_INDEX_URL:-$PIP_INDEX_URL}"
export PIP_DEFAULT_TIMEOUT="${PIP_DEFAULT_TIMEOUT:-100}"

omlx_ok() {
  command -v omlx >/dev/null 2>&1 && omlx --help >/dev/null 2>&1
}

if omlx_ok; then
  echo "已安装可用的 omlx: $(command -v omlx)"
  brew info omlx 2>/dev/null | head -n 8 || true
else
  if [[ "$WITH_KERNEL" == "1" ]]; then
    echo "安装 oMLX HEAD + custom kernel（很慢）..."
    echo "需要完整 Xcode。卡住请 Ctrl+C 后: OMLX_WITH_CUSTOM_KERNEL=0 $0"
    if ! brew install omlx --HEAD --with-custom-kernel; then
      echo "带 kernel 失败，回退稳定版..." >&2
      brew uninstall --ignore-dependencies omlx 2>/dev/null || true
      brew install omlx
    fi
  else
    echo "安装 oMLX 稳定版 ..."
    if brew list --versions omlx >/dev/null 2>&1; then
      ver="$(brew list --versions omlx 2>/dev/null || true)"
      if echo "$ver" | grep -q HEAD; then
        echo "发现半成品 HEAD，先卸载: $ver"
        brew uninstall --ignore-dependencies omlx || true
      fi
    fi
    brew install omlx
  fi
fi

if ! omlx_ok; then
  echo "安装后仍无法运行 omlx。" >&2
  echo "建议改用 DMG: https://github.com/jundot/omlx/releases" >&2
  exit 1
fi

echo ""
echo "验证 CLI:"
command -v omlx
omlx --help 2>/dev/null | head -n 20 || true

echo ""
echo "可选：验证 custom kernel"
python3 -c "from omlx.custom_kernels import native_kernel_status; print(native_kernel_status())" 2>/dev/null \
  || echo "（无 custom kernel 也可正常推理 Qwen3.5）"

echo ""
echo "完成。下一步:"
echo "  ./scripts/download-models.sh hf-mirror"
echo "  ./scripts/start.sh"
