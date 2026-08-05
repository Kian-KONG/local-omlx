---
name: local-verify
description: Use after local code changes to reproduce, validate narrowly, and report residual risk.
---

# Local verification

1. Before editing, state one falsifiable hypothesis and the cheapest check that could disconfirm it.
2. After the first edit, run the narrowest relevant test, typecheck, lint, or syntax check.
3. If it fails, repair the same slice and rerun that check before expanding scope.
4. Report what was verified and any unverified behavior briefly; do not claim a network or integration check that was not run.
