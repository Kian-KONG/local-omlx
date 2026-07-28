#!/usr/bin/env bash
# 列出 oMLX 模型并提示 9B↔4B 切换（CoPaw / 客户端选 model id）
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$ROOT_DIR/.env" ]]; then
  # shellcheck disable=SC1091
  set -a && source "$ROOT_DIR/.env" && set +a
fi

HOST="${OMLX_HOST:-127.0.0.1}"
PORT="${OMLX_PORT:-8000}"
BASE="http://${HOST}:${PORT}"
TARGET="${1:-}" # 9b | 4b | 35b | status | ""

MODEL_9B_NAME="Qwen3.5-9B-OptiQ-4bit"
MODEL_4B_NAME="Qwen3.5-4B-OptiQ-4bit"
MODEL_35B_NAME="Qwen3.5-35B-A3B-OptiQ-4bit"

if ! curl -fsS "$BASE/v1/models" >/dev/null 2>&1; then
  echo "oMLX 未就绪: $BASE/v1/models" >&2
  echo "请先: ./scripts/start.sh" >&2
  exit 1
fi

echo "=== 可用模型 ($BASE/v1/models) ==="
if command -v python3 >/dev/null 2>&1; then
  curl -fsS "$BASE/v1/models" | python3 -c '
import json,sys
data=json.load(sys.stdin)
for m in data.get("data", data if isinstance(data, list) else []):
    mid = m.get("id") if isinstance(m, dict) else m
    print("-", mid)
' 2>/dev/null || curl -fsS "$BASE/v1/models"
else
  curl -fsS "$BASE/v1/models"
fi
echo ""

# 尝试通过 admin API 卸载/加载（若版本支持；失败则仅打印客户端用法）
try_admin_unload() {
  local name="$1"
  # 常见路径尝试；不同 oMLX 版本可能不同
  for path in \
    "/admin/api/models/${name}/unload" \
    "/api/models/${name}/unload" \
    "/v1/models/${name}/unload"; do
    if curl -fsS -X POST "$BASE$path" >/dev/null 2>&1; then
      echo "已请求卸载: $name ($path)"
      return 0
    fi
  done
  return 1
}

print_client_hint() {
  local prefer="$1"
  cat <<EOF
--- 客户端如何「切换」---
oMLX 按请求里的 model 字段加载；同时只保留一个大模型在内存。

推荐 model id:
  4B（CoPaw / Codex / 多进程）: $MODEL_4B_NAME
  9B（16GB 空机 / 36GB Agent）: $MODEL_9B_NAME
  35B-A3B（仅 36GB+ 空机）: $MODEL_35B_NAME

OpenAI 示例:
  curl -s $BASE/v1/chat/completions \\
    -H 'Content-Type: application/json' \\
    -H \"Authorization: Bearer \${OMLX_API_KEY}\" \\
    -d '{"model":"$prefer","messages":[{"role":"user","content":"你好"}],"max_tokens":64}'

CoPaw / Codex: 选对应 model id
  详见: configs/copaw-provider.md / configs/machines.md

Admin: $BASE/admin → Models → Unload 不用的模型
EOF
}

auth_hdr=()
if [[ -n "${OMLX_API_KEY:-}" ]]; then
  auth_hdr=(-H "Authorization: Bearer ${OMLX_API_KEY}")
fi

case "$TARGET" in
  ""|status)
    print_client_hint "$MODEL_4B_NAME"
    ;;
  4b|4B)
    echo "目标: 4B（适合 CoPaw / Codex）"
    try_admin_unload "$MODEL_9B_NAME" || true
    try_admin_unload "$MODEL_35B_NAME" || true
    print_client_hint "$MODEL_4B_NAME"
    echo ""
    echo "冒烟测试 4B ..."
    curl -fsS "$BASE/v1/chat/completions" \
      "${auth_hdr[@]}" \
      -H 'Content-Type: application/json' \
      -d "{\"model\":\"$MODEL_4B_NAME\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply with OK\"}],\"max_tokens\":16}" \
      | head -c 800 || true
    echo ""
    ;;
  9b|9B)
    echo "目标: 9B（Unload 其他大模型）"
    try_admin_unload "$MODEL_4B_NAME" || true
    try_admin_unload "$MODEL_35B_NAME" || true
    print_client_hint "$MODEL_9B_NAME"
    echo ""
    echo "冒烟测试 9B ..."
    curl -fsS "$BASE/v1/chat/completions" \
      "${auth_hdr[@]}" \
      -H 'Content-Type: application/json' \
      -d "{\"model\":\"$MODEL_9B_NAME\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply with OK\"}],\"max_tokens\":16}" \
      | head -c 800 || true
    echo ""
    ;;
  35b|35B)
    echo "目标: 35B-A3B（需 36GB+，Unload 其他模型，少开 CoPaw）"
    try_admin_unload "$MODEL_4B_NAME" || true
    try_admin_unload "$MODEL_9B_NAME" || true
    print_client_hint "$MODEL_35B_NAME"
    echo ""
    echo "冒烟测试 35B ..."
    curl -fsS "$BASE/v1/chat/completions" \
      "${auth_hdr[@]}" \
      -H 'Content-Type: application/json' \
      -d "{\"model\":\"$MODEL_35B_NAME\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply with OK\"}],\"max_tokens\":16}" \
      | head -c 800 || true
    echo ""
    ;;
  *)
    echo "用法: $0 [status|4b|9b|35b]" >&2
    exit 1
    ;;
esac
