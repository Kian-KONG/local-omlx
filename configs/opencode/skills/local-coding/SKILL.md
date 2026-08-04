---
name: local-coding
description: Use when editing code on a memory-limited local model (oMLX / Qwen). Prefer small diffs, few files, and grep-first navigation.
---

# Local coding (memory-limited)

1. Locate with `grep` / `glob` first; `read` only the needed slices.
2. Change the smallest set of files; prefer short patches over rewrites.
3. Do not dump whole directories into context. Do not open heavy skills packs.
4. After edits, run the project's lightest check (typecheck / single test) via `bash` if useful.
5. Keep answers brief: file list + what changed + why.
