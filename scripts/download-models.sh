#!/usr/bin/env bash
# 下载 Qwen OptiQ / 量化 MLX 模型到 oMLX 模型目录（默认同 DMG：~/.omlx/models）
#
# 用法:
#   ./scripts/download-models.sh [hf-mirror|modelscope] [profile|size]
#
# profile/size:
#   mini16 | both     → 4B + 9B（16GB Mac Mini）
#   36-2bit | qwen36  → Qwen3.6-35B-A3B 2bit（约 11GB，16GB 可跑）
#   pro36             → 4B + 9B + Qwen3.5-35B-A3B OptiQ-4bit（36GB+）
#   4b | 9b | 35b | 36-2bit → 单个模型
#
# 也可只在 oMLX Admin 里下载；本脚本便于多机复用与国内镜像。
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$ROOT_DIR/.env" ]]; then
  # shellcheck disable=SC1091
  set -a && source "$ROOT_DIR/.env" && set +a
fi

MODEL_DIR="${OMLX_MODEL_DIR:-$HOME/.omlx/models}"
SOURCE="${1:-${OMLX_DOWNLOAD_SOURCE:-hf-mirror}}"
PIP_INDEX_URL="${PIP_INDEX_URL:-https://pypi.tuna.tsinghua.edu.cn/simple}"
WHICH="${2:-mini16}"
VENV_DIR="${OMLX_DOWNLOAD_VENV:-$ROOT_DIR/.venv-download}"

MODEL_9B="${OMLX_MODEL_9B:-mlx-community/Qwen3.5-9B-OptiQ-4bit}"
MODEL_4B="${OMLX_MODEL_4B:-mlx-community/Qwen3.5-4B-OptiQ-4bit}"
MODEL_35B="${OMLX_MODEL_35B:-mlx-community/Qwen3.5-35B-A3B-OptiQ-4bit}"
# Qwen3.6-35B-A3B 最小量化（~11GB），16GB Mac 可选
MODEL_36_2BIT="${OMLX_MODEL_36_2BIT:-majentik/Qwen3.6-35B-A3B-RotorQuant-MLX-2bit}"

MS_9B="${OMLX_MODELSCOPE_9B:-$MODEL_9B}"
MS_4B="${OMLX_MODELSCOPE_4B:-$MODEL_4B}"
MS_35B="${OMLX_MODELSCOPE_35B:-$MODEL_35B}"
MS_36_2BIT="${OMLX_MODELSCOPE_36_2BIT:-$MODEL_36_2BIT}"

mkdir -p "$MODEL_DIR"

usage() {
  cat <<EOF
用法: $0 [hf-mirror|modelscope] [mini16|pro36|both|4b|9b|35b|36-2bit|qwen36]

  mini16 / both  4B + 9B（约 12GB 盘，适合 16GB）
  36-2bit / qwen36  Qwen3.6-35B-A3B 2bit（约 11GB，16GB 可跑）
  pro36          4B + 9B + Qwen3.5-35B OptiQ-4bit（约 33GB 盘，适合 36GB+）
  4b | 9b | 35b | 36-2bit  只下对应模型
  Ctrl+C          优雅暂停（保留断点，再次运行同一命令即可续传）

环境变量: OMLX_MODEL_DIR HF_ENDPOINT PIP_INDEX_URL
默认目录: ~/.omlx/models（与 oMLX DMG 一致）
EOF
}

ensure_venv() {
  if [[ ! -x "$VENV_DIR/bin/python" ]]; then
    echo "创建下载用 venv: $VENV_DIR"
    python3 -m venv "$VENV_DIR"
  fi
  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"
  if [[ -n "${PIP_INDEX_URL}" ]]; then
    python -m pip install -q -U pip -i "$PIP_INDEX_URL"
  else
    python -m pip install -q -U pip
  fi
}

pip_install() {
  ensure_venv
  if [[ -n "${PIP_INDEX_URL}" ]]; then
    python -m pip install -q -i "$PIP_INDEX_URL" "$@"
  else
    python -m pip install -q "$@"
  fi
}

repo_basename() {
  local id="$1"
  echo "${id##*/}"
}

DOWNLOAD_PID=""
DOWNLOAD_TARGET=""

clear_stale_locks() {
  local dir="$1"
  [[ -d "$dir/.cache" ]] || return 0
  find "$dir/.cache" -name '*.lock' -type f -delete 2>/dev/null || true
}

graceful_pause() {
  echo ""
  echo "[pause] 正在优雅暂停下载..."
  if [[ -n "${DOWNLOAD_PID:-}" ]] && kill -0 "$DOWNLOAD_PID" 2>/dev/null; then
    kill -TERM "$DOWNLOAD_PID" 2>/dev/null || true
    local i
    for i in $(seq 1 30); do
      kill -0 "$DOWNLOAD_PID" 2>/dev/null || break
      sleep 0.5
    done
    if kill -0 "$DOWNLOAD_PID" 2>/dev/null; then
      echo "[pause] 仍未退出，发送 SIGKILL..."
      kill -KILL "$DOWNLOAD_PID" 2>/dev/null || true
    fi
    wait "$DOWNLOAD_PID" 2>/dev/null || true
  fi
  if [[ -n "${DOWNLOAD_TARGET:-}" ]]; then
    clear_stale_locks "$DOWNLOAD_TARGET"
    echo "[pause] 已暂停。进度约 $(du -sh "$DOWNLOAD_TARGET" 2>/dev/null | awk '{print $1}')"
  else
    echo "[pause] 已暂停。"
  fi
  echo "[pause] 恢复: 重新运行同一命令即可续传"
  exit 130
}

run_download() {
  local target="$1"
  shift
  DOWNLOAD_TARGET="$target"
  clear_stale_locks "$target"
  trap graceful_pause INT TERM
  "$@" &
  DOWNLOAD_PID=$!
  local ec=0
  wait "$DOWNLOAD_PID" || ec=$?
  trap - INT TERM
  DOWNLOAD_PID=""
  return "$ec"
}

is_downloaded() {
  local dir="$1"
  [[ -d "$dir" ]] || return 1
  [[ -f "$dir/config.json" ]] || return 1
  # 仍有未完成分片则视为未下载完
  if find "$dir" -name '*.incomplete' 2>/dev/null | grep -q .; then
    return 1
  fi

  local index="$dir/model.safetensors.index.json"
  if [[ -f "$index" ]]; then
    # All shards listed in weight_map must exist under $dir
    python3 - "$dir" "$index" <<'PY'
import json, os, sys
root, index_path = sys.argv[1], sys.argv[2]
with open(index_path) as f:
    idx = json.load(f)
shards = set(idx.get("weight_map", {}).values())
if not shards:
    sys.exit(1)
for s in shards:
    if not os.path.isfile(os.path.join(root, s)):
        sys.exit(1)
sys.exit(0)
PY
    return $?
  fi

  compgen -G "$dir/*.safetensors" >/dev/null 2>&1 \
    || compgen -G "$dir/model*.safetensors" >/dev/null 2>&1
}

download_hf_mirror() {
  local repo_id="$1"
  local local_name
  local_name="$(repo_basename "$repo_id")"
  local target="$MODEL_DIR/$local_name"

  if is_downloaded "$target"; then
    echo "已存在: $target"
    return 0
  fi

  export HF_ENDPOINT="${HF_ENDPOINT:-https://hf-mirror.com}"
  export HF_HUB_DISABLE_XET="${HF_HUB_DISABLE_XET:-1}"
  echo "从 hf-mirror 下载 $repo_id → $target ..."
  echo "  HF_ENDPOINT=$HF_ENDPOINT"

  pip_install -U "huggingface_hub[cli]"

  clear_stale_locks "$target"

  if command -v hf >/dev/null 2>&1; then
    run_download "$target" hf download "$repo_id" --local-dir "$target"
  else
    run_download "$target" huggingface-cli download \
      --resume-download \
      "$repo_id" \
      --local-dir "$target" \
      --local-dir-use-symlinks False
  fi

  if is_downloaded "$target"; then
    echo "完成: $target ($(du -sh "$target" | awk '{print $1}'))"
  else
    echo "下载后未找到完整 MLX 权重: $target" >&2
    exit 1
  fi
}

download_modelscope() {
  local repo_id="$1"
  local local_name
  local_name="$(repo_basename "$repo_id")"
  local target="$MODEL_DIR/$local_name"

  if is_downloaded "$target"; then
    echo "已存在: $target"
    return 0
  fi

  echo "从 ModelScope 下载 $repo_id → $target ..."
  pip_install -U modelscope

  clear_stale_locks "$target"
  if ! run_download "$target" modelscope download --model "$repo_id" --local_dir "$target"; then
    echo "" >&2
    echo "ModelScope 下载失败。请改用: $0 hf-mirror $WHICH" >&2
    exit 1
  fi

  if is_downloaded "$target"; then
    echo "完成: $target ($(du -sh "$target" | awk '{print $1}'))"
  else
    echo "下载后未找到完整 MLX 权重: $target" >&2
    exit 1
  fi
}

download_one() {
  local hf_id="$1"
  local ms_id="$2"
  case "$SOURCE" in
    hf-mirror) download_hf_mirror "$hf_id" ;;
    modelscope) download_modelscope "$ms_id" ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
}

case "$SOURCE" in
  -h|--help|help) usage; exit 0 ;;
esac

case "$WHICH" in
  mini16|both)
    download_one "$MODEL_4B" "$MS_4B"
    download_one "$MODEL_9B" "$MS_9B"
    ;;
  pro36)
    download_one "$MODEL_4B" "$MS_4B"
    download_one "$MODEL_9B" "$MS_9B"
    download_one "$MODEL_35B" "$MS_35B"
    ;;
  4b|4B) download_one "$MODEL_4B" "$MS_4B" ;;
  9b|9B) download_one "$MODEL_9B" "$MS_9B" ;;
  35b|35B|35b-a3b|35B-A3B) download_one "$MODEL_35B" "$MS_35B" ;;
  36-2bit|36_2bit|qwen36|qwen3.6|Qwen36)
    download_one "$MODEL_36_2BIT" "$MS_36_2BIT"
    ;;
  -h|--help|help) usage; exit 0 ;;
  *)
    usage >&2
    exit 1
    ;;
esac

echo ""
echo "模型目录: $MODEL_DIR"
ls -la "$MODEL_DIR" || true
echo ""
echo "若 oMLX 已在跑仍看不到模型：重启 oMLX，或 Admin 刷新。"
echo "验证: curl -s -H \"Authorization: Bearer \$OMLX_API_KEY\" http://127.0.0.1:8000/v1/models"
