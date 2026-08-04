#!/usr/bin/env bash
# 启动 oMLX：OpenAI 兼容网关 + 16GB 内存护栏
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$ROOT_DIR/.env" ]]; then
  # shellcheck disable=SC1091
  set -a && source "$ROOT_DIR/.env" && set +a
fi

MODEL_DIR="${OMLX_MODEL_DIR:-$HOME/.omlx/models}"
HOST="${OMLX_HOST:-127.0.0.1}"
PORT="${OMLX_PORT:-8000}"
HF_ENDPOINT="${HF_ENDPOINT:-https://hf-mirror.com}"
MEMORY_GUARD_GB="${OMLX_MEMORY_GUARD_GB:-10}"
MAX_CONCURRENT="${OMLX_MAX_CONCURRENT_REQUESTS:-2}"
SSD_CACHE="${OMLX_SSD_CACHE_DIR:-$HOME/.omlx/cache}"
# 16GB 建议：进程总上限 ~12GB，模型权重上限 ~10GB（与 User Guide 一致）
MAX_PROCESS_MEMORY="${OMLX_MAX_PROCESS_MEMORY:-12GB}"
MAX_MODEL_MEMORY="${OMLX_MAX_MODEL_MEMORY:-10GB}"
PID_FILE="${OMLX_PID_FILE:-$HOME/.omlx/local-omlx.pid}"
LOG_FILE="${OMLX_LOG_FILE:-$HOME/.omlx/logs/local-omlx.log}"
FOREGROUND="${OMLX_FOREGROUND:-0}"

mkdir -p "$MODEL_DIR" "$SSD_CACHE" "$(dirname "$PID_FILE")" "$(dirname "$LOG_FILE")"

if ! command -v omlx >/dev/null 2>&1; then
  echo "未找到 omlx。请先运行: ./scripts/install-omlx.sh" >&2
  exit 1
fi

if [[ ! -d "$MODEL_DIR" ]] || [[ -z "$(ls -A "$MODEL_DIR" 2>/dev/null || true)" ]]; then
  echo "模型目录为空: $MODEL_DIR" >&2
  echo "请先: ./scripts/download-models.sh hf-mirror" >&2
  exit 1
fi

if curl -fsS "http://${HOST}:${PORT}/v1/models" >/dev/null 2>&1; then
  echo "oMLX 似乎已在运行: http://${HOST}:${PORT}/v1"
  curl -s "http://${HOST}:${PORT}/v1/models" | head -c 500
  echo ""
  exit 0
fi

if [[ -f "$PID_FILE" ]]; then
  old_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
    echo "已有进程 PID $old_pid（$PID_FILE）。若异常请先 ./scripts/stop.sh" >&2
    exit 1
  fi
  rm -f "$PID_FILE"
fi

# 探测可选 flag，兼容不同 oMLX 版本
omlx_help="$(omlx serve --help 2>&1 || true)"
has_flag() { echo "$omlx_help" | grep -q -- "$1"; }

ARGS=(
  serve
  --model-dir "$MODEL_DIR"
  --host "$HOST"
  --port "$PORT"
  --hf-endpoint "$HF_ENDPOINT"
  --paged-ssd-cache-dir "$SSD_CACHE"
  --max-concurrent-requests "$MAX_CONCURRENT"
)

if has_flag "--memory-guard-gb"; then
  ARGS+=(--memory-guard-gb "$MEMORY_GUARD_GB")
fi
if has_flag "--max-process-memory" && [[ -n "$MAX_PROCESS_MEMORY" ]]; then
  ARGS+=(--max-process-memory "$MAX_PROCESS_MEMORY")
fi
if has_flag "--max-model-memory" && [[ -n "$MAX_MODEL_MEMORY" ]]; then
  ARGS+=(--max-model-memory "$MAX_MODEL_MEMORY")
fi

if [[ -n "${OMLX_API_KEY:-}" ]]; then
  ARGS+=(--api-key "$OMLX_API_KEY")
fi

export HF_ENDPOINT
export OMLX_MODEL_DIR="$MODEL_DIR"
export OMLX_PORT="$PORT"
export OMLX_HOST="$HOST"

echo "启动 oMLX ..."
echo "  model-dir:     $MODEL_DIR"
echo "  endpoint:      http://${HOST}:${PORT}/v1"
echo "  memory-guard:  ${MEMORY_GUARD_GB} GB"
echo "  process/model: ${MAX_PROCESS_MEMORY} / ${MAX_MODEL_MEMORY}"
echo "  concurrent:    $MAX_CONCURRENT"
echo "  ssd-cache:     $SSD_CACHE"
echo "  hf-endpoint:   $HF_ENDPOINT"
echo "  log:           $LOG_FILE"
echo ""
echo "提示: 16GB 上不要同时 pin 9B 与 4B；开 CoPaw 请用 ./scripts/switch-model.sh 4b"

if [[ "$FOREGROUND" == "1" ]]; then
  exec omlx "${ARGS[@]}"
fi

nohup omlx "${ARGS[@]}" >>"$LOG_FILE" 2>&1 &
echo $! >"$PID_FILE"
echo "已后台启动 PID $(cat "$PID_FILE")"

auth_hdr=()
if [[ -n "${OMLX_API_KEY:-}" ]]; then
  auth_hdr=(-H "Authorization: Bearer ${OMLX_API_KEY}")
fi

# 等待就绪（首次加载可能较慢）
for _ in $(seq 1 90); do
  if curl -fsS "${auth_hdr[@]}" "http://${HOST}:${PORT}/v1/models" >/dev/null 2>&1; then
    echo "就绪: http://${HOST}:${PORT}/v1/models"
    echo "Admin: http://${HOST}:${PORT}/admin"
    exit 0
  fi
  # 进程已退出则失败
  if [[ -f "$PID_FILE" ]]; then
    pid="$(cat "$PID_FILE")"
    if ! kill -0 "$pid" 2>/dev/null; then
      echo "oMLX 进程已退出，请查看日志: $LOG_FILE" >&2
      tail -n 40 "$LOG_FILE" 2>/dev/null || true
      exit 1
    fi
  fi
  sleep 1
done

echo "启动超时，请查看日志: $LOG_FILE" >&2
tail -n 40 "$LOG_FILE" 2>/dev/null || true
exit 1
