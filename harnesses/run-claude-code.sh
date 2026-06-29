#!/usr/bin/env bash
# Claude Code → local model via the Anthropic-compatible endpoint.
# args: WORKDIR MODEL OPENAI_URL ANTHROPIC_URL TASK
set -euo pipefail
WORK="$1"; MODEL="$2"; ANTHROPIC_URL="$4"; TASK="$5"
cd "$WORK"
env ANTHROPIC_BASE_URL="$ANTHROPIC_URL" \
    ANTHROPIC_AUTH_TOKEN=dummy ANTHROPIC_API_KEY=dummy \
    ANTHROPIC_MODEL="$MODEL" \
  claude -p "$TASK" --model "$MODEL" --dangerously-skip-permissions
