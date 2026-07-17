#!/bin/bash
# Wraps an agent-driven cron job whose log is freeform LLM prose and appends a
# deterministic end-of-run marker — the only line the ops digest grades.
# Usage: run_with_marker.sh <label> <command> [args...]
label="$1"; shift
"$@"
rc=$?
if [ "$rc" -eq 0 ]; then
  echo "=== ${label} $(date +%Y%m%d-%H%M%S) OK ==="
else
  echo "=== ${label} $(date +%Y%m%d-%H%M%S) FAILED (exit ${rc}) ==="
fi
exit $rc
