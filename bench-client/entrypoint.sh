#!/usr/bin/env bash
# bench-client entrypoint. Runs ONE harness against ONE engine (reachable by
# compose service name) on the bug-fix task, scores it, appends a result row.
# Env: ENGINE {ds4|vllm|ollama}  HARNESS {claude-code|opencode|qwen-code|minion}
#      MODEL (engine-specific)    TASK (optional; defaults to bench/task.md)
set -uo pipefail

ENGINE="${ENGINE:?set ENGINE}"; HARNESS="${HARNESS:?set HARNESS}"

case "$ENGINE" in
  ds4)    HOST=ds4;    PORT=8080;  MODEL="${MODEL:-deepseek-v4-flash}";;
  vllm)   HOST=vllm;   PORT=8000;  MODEL="${MODEL:-gemma-26b}";;
  ollama) HOST=ollama; PORT=11434; MODEL="${MODEL:-qwen3-coder-next:latest}";;
  *) echo "unknown ENGINE $ENGINE"; exit 2;;
esac
OPENAI_URL="http://$HOST:$PORT/v1"; ANTHROPIC_URL="http://$HOST:$PORT"
TASK="${TASK:-$(cat /lab/seed/bench/task.md)}"

# fresh, isolated copy of the demo repo each run (never mutate the seed)
WORK=/tmp/work; rm -rf "$WORK"; mkdir -p "$WORK"
cp /lab/seed/bench/demo-repo/* "$WORK"/
cp "$WORK/todo.py.bug" "$WORK/todo.py"; rm -f "$WORK/todo.py.bug"   # ALWAYS start from the canonical bug (contamination-proof)
echo "[bench] start state:"; ( cd "$WORK" && uv run --with pytest python -m pytest -q | tail -1 ) || true

echo "[bench] $HARNESS × $ENGINE ($MODEL) → $OPENAI_URL"
START=$(date +%s)
/lab/harnesses/run-"$HARNESS".sh "$WORK" "$MODEL" "$OPENAI_URL" "$ANTHROPIC_URL" "$TASK" || true
WALL=$(( $(date +%s) - START ))

PASS=$( cd "$WORK" && uv run --with pytest python -m pytest -q 2>&1 | tail -1 || true )
echo "==================== RESULT ===================="
printf "%s × %s  model=%s\nwall=%ss  tests: %s\n" "$HARNESS" "$ENGINE" "$MODEL" "$WALL" "$PASS"
echo "================================================"
mkdir -p /lab/results
printf "| %s | %s | %s | %ss | %s |\n" "$HARNESS" "$ENGINE" "$MODEL" "$WALL" "$PASS" >> /lab/results/RUN-LOG.md
