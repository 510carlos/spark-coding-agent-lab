#!/usr/bin/env bash
# OpenCode → local model via a generated OpenAI-compatible provider config.
# args: WORKDIR MODEL OPENAI_URL ANTHROPIC_URL TASK
set -euo pipefail
WORK="$1"; MODEL="$2"; OPENAI_URL="$3"; TASK="$5"
cd "$WORK"
command -v opencode >/dev/null || npm install -g opencode-ai

mkdir -p "$HOME/.config/opencode"
cat > "$HOME/.config/opencode/opencode.json" <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "provider": {
    "local": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Local (spark-coding-agent-lab)",
      "options": { "baseURL": "$OPENAI_URL" },
      "models": { "$MODEL": { "name": "$MODEL" } }
    }
  },
  "permission": { "edit": "allow", "bash": "allow", "webfetch": "allow" }
}
EOF
opencode run -m "local/$MODEL" "$TASK"
