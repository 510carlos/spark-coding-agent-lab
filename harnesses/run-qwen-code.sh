#!/usr/bin/env bash
# Qwen Code → local model via the OpenAI-compatible endpoint.
# args: WORKDIR MODEL OPENAI_URL ANTHROPIC_URL TASK
set -euo pipefail
WORK="$1"; MODEL="$2"; OPENAI_URL="$3"; TASK="$5"
cd "$WORK"
command -v qwen >/dev/null || npm install -g @qwen-code/qwen-code
env OPENAI_API_KEY=local OPENAI_BASE_URL="$OPENAI_URL" OPENAI_MODEL="$MODEL" \
    QWEN_CODE_SUPPRESS_YOLO_WARNING=1 \
  qwen --approval-mode yolo -m "$MODEL" "$TASK"
