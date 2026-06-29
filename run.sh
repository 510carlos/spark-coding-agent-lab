#!/usr/bin/env bash
# spark-coding-agent-lab — run ONE engine × ONE harness on the bug-fix bench.
# Enforces one-engine-at-a-time (mandatory on a 128 GB Spark).
set -euo pipefail

ENGINE=""; HARNESS=""; MODEL=""
while [[ $# -gt 0 ]]; do case "$1" in
  --engine)  ENGINE="$2"; shift 2;;
  --harness) HARNESS="$2"; shift 2;;
  --model)   MODEL="$2"; shift 2;;
  *) echo "unknown arg: $1"; exit 2;;
esac; done
[[ -z "$ENGINE" || -z "$HARNESS" ]] && { echo "usage: run.sh --engine {ds4|vllm|ollama} --harness {claude-code|opencode|qwen-code|minion} [--model NAME]"; exit 2; }

LAB="$(cd "$(dirname "$0")" && pwd)"
WORK="$LAB/bench/demo-repo"
TASK="$(cat "$LAB/bench/task.md")"
TS="$(date +%Y%m%d-%H%M%S)"
OUT="$LAB/results/runs/${TS}-${ENGINE}-${HARNESS}.txt"
mkdir -p "$LAB/results/runs"

# ---- 1. ONE ENGINE AT A TIME: stop every engine EXCEPT the one requested ---
echo "[lab] stopping other engines (one-engine-at-a-time)…"
[[ "$ENGINE" != ds4 ]]    && { pkill -f ds4-server 2>/dev/null || true; }
[[ "$ENGINE" != vllm ]]   && { docker stop vllm-spark 2>/dev/null || true; }
if [[ "$ENGINE" != ollama ]]; then
  for m in $(ollama ps 2>/dev/null | awk 'NR>1{print $1}'); do ollama stop "$m" 2>/dev/null || true; done
fi
sleep 2

# ---- 2. start the requested engine + resolve endpoint ---------------------
case "$ENGINE" in
  ds4)
    MODEL="${MODEL:-deepseek-v4-flash}"
    OPENAI_URL="http://localhost:8080/v1"; ANTHROPIC_URL="http://localhost:8080"
    "$LAB/engines/ds4/serve.sh" & ;;
  vllm)
    MODEL="${MODEL:-gemma-26b}"
    OPENAI_URL="http://localhost:8000/v1"; ANTHROPIC_URL="http://localhost:8000"
    "$LAB/engines/vllm-spark/serve.sh" ;;
  ollama)
    MODEL="${MODEL:-qwen3-coder-next:latest}"
    OPENAI_URL="http://localhost:11434/v1"; ANTHROPIC_URL="http://localhost:11434"
    pgrep -x ollama >/dev/null || (ollama serve >/dev/null 2>&1 &)
    sleep 3 ;;   # model loads on the harness's first request
  *) echo "unknown engine $ENGINE"; exit 2;;
esac

echo "[lab] waiting for $ENGINE endpoint…"
for i in $(seq 1 120); do curl -sf --max-time 2 "$OPENAI_URL/models" >/dev/null 2>&1 && break; sleep 3; done

# ---- 3. reset the demo repo to the planted-bug state ----------------------
echo "[lab] resetting demo-repo to planted-bug state…"
cp "$WORK/todo.py.bug" "$WORK/todo.py"   # always start from the canonical bug state
( cd "$WORK" && uv run --with pytest python -m pytest -q | tail -1 ) || true   # bug state fails 2 tests; that's expected

# ---- 4. run the chosen harness against the endpoint -----------------------
echo "[lab] running $HARNESS × $ENGINE ($MODEL)…"
START=$(date +%s)
"$LAB/harnesses/run-${HARNESS}.sh" "$WORK" "$MODEL" "$OPENAI_URL" "$ANTHROPIC_URL" "$TASK" > "$OUT" 2>&1 || true
WALL=$(( $(date +%s) - START ))

# ---- 5. score -------------------------------------------------------------
PASS=$( cd "$WORK" && uv run --with pytest python -m pytest -q 2>&1 | tail -1 || true )
echo ""
echo "==================== RESULT ===================="
printf "%-12s × %-11s  model=%s\n" "$HARNESS" "$ENGINE" "$MODEL"
printf "wall=%ss   tests: %s\n" "$WALL" "$PASS"
echo "transcript: $OUT"
echo "================================================"
# append a row to the matrix
printf "| %s | %s | %s | %ss | %s |\n" "$HARNESS" "$ENGINE" "$MODEL" "$WALL" "$PASS" >> "$LAB/results/RUN-LOG.md"
