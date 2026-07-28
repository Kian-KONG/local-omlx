# download-models.sh Graceful Pause Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Ctrl+C graceful pause (preserve resume) and tighten `is_downloaded` in `scripts/download-models.sh`.

**Architecture:** Run `hf`/`modelscope` as a background child under `trap INT TERM`; on signal TERM→wait≤15s→KILL, clear stale `.lock`, exit 130. Before each download, clear stale locks. `is_downloaded` requires `config.json` plus all shards from `model.safetensors.index.json` when present.

**Tech Stack:** Bash (`set -euo pipefail`), huggingface_hub CLI / modelscope CLI, optional python3 for index JSON parse.

## Global Constraints

- Only modify `scripts/download-models.sh` (plus this plan / prior design doc already committed).
- No separate `pause`/`resume` subcommands.
- No Windows `.ps1` changes.
- Pause must exit **130**; keep `.incomplete`; clear `*.lock` under the model `.cache` tree.
- Pause wait budget ≈ **15 seconds** before SIGKILL.

## File Structure

| File | Responsibility |
|------|----------------|
| `scripts/download-models.sh` | All helpers + wire into hf/modelscope download paths |
| `scripts/tests/test-is-downloaded.sh` | Lightweight shell test for `is_downloaded` via extracted functions |

---

### Task 1: Tighten `is_downloaded` + unit test

**Files:**
- Modify: `scripts/download-models.sh` (`is_downloaded`, ~lines 78–83)
- Create: `scripts/tests/test-is-downloaded.sh`

**Interfaces:**
- Consumes: none
- Produces: `is_downloaded(dir)` — exit 0 iff complete; exit 1 otherwise

- [ ] **Step 1: Write the failing test harness**

Create `scripts/tests/test-is-downloaded.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# Source only the helpers by extracting them into a temp snippet, OR
# define a local copy matching the planned is_downloaded for TDD of the contract.
# Prefer: source a shared fragment. For this repo, duplicate the expected function
# under test by extracting from the script after implementation; first fail by
# asserting against current behavior via a fixture.

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Fixture: partial 35B-like layout (config + one shard + index listing two shards)
PARTIAL="$TMP/partial"
mkdir -p "$PARTIAL"
echo '{}' >"$PARTIAL/config.json"
cat >"$PARTIAL/model.safetensors.index.json" <<'EOF'
{"weight_map": {"a": "model-00001-of-00002.safetensors", "b": "model-00002-of-00002.safetensors"}}
EOF
: >"$PARTIAL/model-00001-of-00002.safetensors"

# Source helpers from download-models by running a small extractor:
# shellcheck disable=SC1091
eval "$(sed -n '/^is_downloaded()/,/^}/p' "$ROOT/scripts/download-models.sh")"

if is_downloaded "$PARTIAL"; then
  echo "FAIL: partial model should NOT count as downloaded" >&2
  exit 1
fi

# Complete fixture
COMPLETE="$TMP/complete"
mkdir -p "$COMPLETE"
cp "$PARTIAL/config.json" "$COMPLETE/"
cp "$PARTIAL/model.safetensors.index.json" "$COMPLETE/"
: >"$COMPLETE/model-00001-of-00002.safetensors"
: >"$COMPLETE/model-00002-of-00002.safetensors"

if ! is_downloaded "$COMPLETE"; then
  echo "FAIL: complete model should count as downloaded" >&2
  exit 1
fi

# No-index single-file model
SINGLE="$TMP/single"
mkdir -p "$SINGLE"
echo '{}' >"$SINGLE/config.json"
: >"$SINGLE/model.safetensors"
if ! is_downloaded "$SINGLE"; then
  echo "FAIL: single-file model should count as downloaded" >&2
  exit 1
fi

echo "PASS: is_downloaded fixtures"
```

- [ ] **Step 2: Run test to verify it fails (current loose logic)**

Run: `bash scripts/tests/test-is-downloaded.sh`

Expected: `FAIL: partial model should NOT count as downloaded` (current `compgen` sees one `*.safetensors` and returns success).

- [ ] **Step 3: Replace `is_downloaded` with tightened version**

Replace the body of `is_downloaded` in `scripts/download-models.sh` with:

```bash
is_downloaded() {
  local dir="$1"
  [[ -d "$dir" ]] || return 1
  [[ -f "$dir/config.json" ]] || return 1

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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash scripts/tests/test-is-downloaded.sh`

Expected: `PASS: is_downloaded fixtures`

- [ ] **Step 5: Commit**

```bash
git add scripts/download-models.sh scripts/tests/test-is-downloaded.sh
git commit -m "$(cat <<'EOF'
Tighten is_downloaded to require all index shards.

EOF
)"
```

---

### Task 2: Add pause helpers (`clear_stale_locks`, `graceful_pause`, `run_download`)

**Files:**
- Modify: `scripts/download-models.sh` (insert after `repo_basename`, before `is_downloaded`)

**Interfaces:**
- Consumes: global `DOWNLOAD_PID`, `DOWNLOAD_TARGET` (set by `run_download`)
- Produces:
  - `clear_stale_locks(dir)` — deletes `dir/.cache/**/*.lock` (ignore errors)
  - `graceful_pause()` — TERM child → wait ≤15s → KILL → clear locks → exit 130
  - `run_download(target, cmd...)` — sets trap, backgrounds cmd, waits, clears trap

- [ ] **Step 1: Insert helper functions**

Add after `repo_basename`:

```bash
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
```

- [ ] **Step 2: Sanity-check syntax**

Run: `bash -n scripts/download-models.sh`

Expected: no output, exit 0

- [ ] **Step 3: Commit**

```bash
git add scripts/download-models.sh
git commit -m "$(cat <<'EOF'
Add graceful Ctrl+C pause helpers for model downloads.

EOF
)"
```

---

### Task 3: Wire helpers into hf / modelscope paths + usage text

**Files:**
- Modify: `scripts/download-models.sh` (`usage`, `download_hf_mirror`, `download_modelscope`)

**Interfaces:**
- Consumes: `run_download`, `clear_stale_locks`, `is_downloaded`
- Produces: pause-aware download entrypoints

- [ ] **Step 1: Update `usage`**

Inside the `usage` heredoc, after the profile lines, add:

```text
  Ctrl+C          优雅暂停（保留断点，再次运行同一命令即可续传）
```

- [ ] **Step 2: Wire `download_hf_mirror`**

Replace the direct `hf` / `huggingface-cli` invocation block with:

```bash
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
```

Keep surrounding `pip_install`, `is_downloaded` checks, and success/failure messages unchanged. Do **not** wrap `pip_install` in `run_download`.

- [ ] **Step 3: Wire `download_modelscope`**

Replace:

```bash
  if ! modelscope download --model "$repo_id" --local_dir "$target"; then
```

with:

```bash
  clear_stale_locks "$target"
  if ! run_download "$target" modelscope download --model "$repo_id" --local_dir "$target"; then
```

Keep the existing failure message and `is_downloaded` post-check.

- [ ] **Step 4: Syntax check + help smoke**

Run:

```bash
bash -n scripts/download-models.sh
./scripts/download-models.sh --help
```

Expected: exit 0; help text includes `Ctrl+C` pause line.

- [ ] **Step 5: Commit**

```bash
git add scripts/download-models.sh
git commit -m "$(cat <<'EOF'
Wire graceful pause into hf and ModelScope download paths.

EOF
)"
```

---

### Task 4: Manual pause/resume verification (against live or dry fixture)

**Files:**
- Test only (no code unless bugs found)

**Interfaces:**
- Consumes: full `scripts/download-models.sh`

- [ ] **Step 1: Confirm no conflicting download OR use existing 35B resume**

If a background `hf download` for 35B is already running from an earlier session, **do not** start a second one. Either:

- Verify that process already has session-level pause, and only smoke-test the **new script** against a tiny public repo into a temp `OMLX_MODEL_DIR`, or
- After the live 35B job finishes/pauses, run the real script.

Recommended smoke (small, fast):

```bash
export OMLX_MODEL_DIR="/tmp/omlx-pause-smoke-$$"
mkdir -p "$OMLX_MODEL_DIR"
# Override to a tiny repo for smoke — temporarily edit is not allowed;
# instead invoke helpers manually OR download a known small mlx stub if available.
# Practical check without large download:
bash -c '
source /dev/null
# Start script with timeout+signal simulation using a sleep stand-in:
DOWNLOAD_TARGET="/tmp/x"; DOWNLOAD_PID=""; 
# Re-run unit test:
bash scripts/tests/test-is-downloaded.sh
'
```

For real pause signal test of `run_download`:

```bash
bash <<'EOF'
set -euo pipefail
# Inline-source the helpers by extracting from script is heavy;
# instead start a fake long download:
ROOT="$(pwd)"
TMP="$(mktemp -d)"
# Extract and eval helpers
eval "$(sed -n '/^DOWNLOAD_PID=/,/^}/p; /^clear_stale_locks/,/^}/p; /^graceful_pause/,/^}/p; /^run_download/,/^}/p' scripts/download-models.sh | head -n 200)"
# Simpler: copy the four functions into this heredoc if sed is fragile.
# Prefer running:
mkdir -p "$TMP/model/.cache/huggingface/download"
: >"$TMP/model/.cache/huggingface/download/x.lock"
run_download "$TMP/model" sleep 60 &
SCRIPT_PID=$!
sleep 1
kill -INT "$SCRIPT_PID"
wait "$SCRIPT_PID" || ec=$?
# Note: run_download is a function; test via a mini wrapper script instead.
EOF
```

Create a one-off wrapper for the signal test (do not commit unless useful):

```bash
cat > /tmp/test-run-download-pause.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
ROOT="/Users/kkn1sgh/Desktop/Workspace/local-omlx"
# shellcheck disable=SC1091
eval "$(python3 - <<'PY'
from pathlib import Path
text = Path("/Users/kkn1sgh/Desktop/Workspace/local-omlx/scripts/download-models.sh").read_text()
# extract from DOWNLOAD_PID= through end of run_download function
start = text.index("DOWNLOAD_PID=")
# find run_download and its closing brace by scanning
idx = text.index("run_download()")
# take from DOWNLOAD_PID to after run_download's closing }
chunk = text[start:]
# naive: print until we've closed run_download — use the script file markers
print(text[start:text.index("\nis_downloaded()")])
PY
)"
TMP=$(mktemp -d)
mkdir -p "$TMP/m/.cache/huggingface/download"
: >"$TMP/m/.cache/huggingface/download/stale.lock"
run_download "$TMP/m" sleep 120 &
WPID=$!
sleep 1
kill -INT $WPID
set +e
wait $WPID
EC=$?
set -e
echo "exit=$EC"
[[ "$EC" == "130" ]] || { echo "expected 130"; exit 1; }
[[ ! -f "$TMP/m/.cache/huggingface/download/stale.lock" ]] || { echo "lock not cleared"; exit 1; }
echo "PASS: pause signal"
EOF
bash /tmp/test-run-download-pause.sh
```

Expected: `exit=130`, `PASS: pause signal`, stale lock removed.

- [ ] **Step 2: Re-run unit test**

Run: `bash scripts/tests/test-is-downloaded.sh`

Expected: `PASS`

- [ ] **Step 3: Commit any bugfixes** (skip if none)

```bash
git add scripts/download-models.sh scripts/tests/test-is-downloaded.sh
git commit -m "$(cat <<'EOF'
Fix graceful pause edge cases found in smoke tests.

EOF
)"
```

---

## Spec Coverage Checklist

| Spec requirement | Task |
|------------------|------|
| Ctrl+C / SIGTERM graceful pause | Task 2–3 |
| Preserve `.incomplete` | Task 2 (`graceful_pause` does not delete them) |
| Clear stale `.lock` on pause and before start | Task 2–3 |
| Exit 130 | Task 2 |
| Resume = re-run same command | Task 3 (usage + behavior) |
| Tighten `is_downloaded` with index shards | Task 1 |
| usage mentions Ctrl+C | Task 3 |
| No pause subcommand / no Windows changes | Global constraints |

## Self-Review

- No TBD placeholders in task steps.
- Function names match design: `clear_stale_locks`, `graceful_pause`, `run_download`, `is_downloaded`.
- Single subsystem; one plan is enough.
