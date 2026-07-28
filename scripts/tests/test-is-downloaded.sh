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
