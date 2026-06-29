#!/usr/bin/env bash
# minion → local model (OpenAI-compatible), driven headlessly via tmux + driver.py.
# args: WORKDIR MODEL OPENAI_URL ANTHROPIC_URL TASK
set -euo pipefail
WORK="$1"; MODEL="$2"; OPENAI_URL="$3"; TASK="$5"
LAB="$(cd "$(dirname "$0")/.." && pwd)"
[[ -d "$HOME/minion" ]] || git clone https://github.com/Sentdex/minion "$HOME/minion"
cd "$WORK"

tmux kill-session -t lab-minion 2>/dev/null || true
tmux new-session -d -s lab-minion -x 200 -y 50 \; set-option -t lab-minion history-limit 200000
tmux send-keys -t lab-minion \
  "cd $WORK && export MINION_BASE_URL=$OPENAI_URL MINION_MODEL=$MODEL MINION_API_KEY=local && \
   uv run --with openai --with 'httpx<0.28' --with pytest python $HOME/minion/minion.py" Enter
for i in $(seq 1 20); do sleep 3; tmux capture-pane -t lab-minion -p | grep -q '0 chars' && break; done

# driver: types the task, auto-approves edit+pytest, caps runaway, dumps transcript
printf '%s' "$TASK" | python3 "$LAB/bench/driver.py" lab-minion /dev/stdout 16 420 act2 10
tmux send-keys -t lab-minion -l '/quit'; sleep 1; tmux kill-session -t lab-minion 2>/dev/null || true
