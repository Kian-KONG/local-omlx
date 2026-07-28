#!/usr/bin/env bash
# 停止本项目启动的 oMLX（或 brew 服务）
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$ROOT_DIR/.env" ]]; then
  # shellcheck disable=SC1091
  set -a && source "$ROOT_DIR/.env" && set +a
fi

HOST="${OMLX_HOST:-127.0.0.1}"
PORT="${OMLX_PORT:-8000}"
PID_FILE="${OMLX_PID_FILE:-$HOME/.omlx/local-omlx.pid}"

stopped=0

if [[ -f "$PID_FILE" ]]; then
  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    echo "停止 PID $pid ..."
    kill "$pid" 2>/dev/null || true
    for _ in $(seq 1 20); do
      if ! kill -0 "$pid" 2>/dev/null; then
        break
      fi
      sleep 0.5
    done
    if kill -0 "$pid" 2>/dev/null; then
      echo "强制结束 PID $pid ..."
      kill -9 "$pid" 2>/dev/null || true
    fi
    stopped=1
  fi
  rm -f "$PID_FILE"
fi

# 兼容 brew services / omlx start 管理的实例
if command -v omlx >/dev/null 2>&1; then
  if omlx stop >/dev/null 2>&1; then
    echo "已执行 omlx stop"
    stopped=1
  fi
fi

# 兜底：按端口回收
if command -v lsof >/dev/null 2>&1; then
  pids="$(lsof -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null || true)"
  if [[ -n "$pids" ]]; then
    echo "结束占用端口 $PORT 的进程: $pids"
    # shellcheck disable=SC2086
    kill $pids 2>/dev/null || true
    sleep 1
    pids="$(lsof -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null || true)"
    if [[ -n "$pids" ]]; then
      # shellcheck disable=SC2086
      kill -9 $pids 2>/dev/null || true
    fi
    stopped=1
  fi
fi

if curl -fsS "http://${HOST}:${PORT}/v1/models" >/dev/null 2>&1; then
  echo "警告: http://${HOST}:${PORT} 仍可访问，请手动检查进程" >&2
  exit 1
fi

if [[ "$stopped" -eq 1 ]]; then
  echo "oMLX 已停止"
else
  echo "未发现运行中的 oMLX（端口 $PORT）"
fi
