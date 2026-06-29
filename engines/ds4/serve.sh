#!/usr/bin/env bash
# Start DS4 (DeepSeek V4 Flash). Prefers a host-native build at ~/ds4 if present
# (fastest on the Spark); otherwise runs the container image.
set -euo pipefail
LAB="$(cd "$(dirname "$0")/../.." && pwd)"
MODEL_GGUF="${DS4_MODEL:-$LAB/models/weights/deepseek-v4-flash.gguf}"
[[ -f "$MODEL_GGUF" ]] || MODEL_GGUF="$HOME/ds4/gguf/DeepSeek-V4-Flash-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8-chat-v2-imatrix.gguf"

if [[ -x "$HOME/ds4/ds4-server" ]]; then
  echo "[ds4] host-native build"
  exec "$HOME/ds4/ds4-server" --cuda -m "$MODEL_GGUF" \
       --ctx 131072 --host 127.0.0.1 --port 8080 --cors
else
  echo "[ds4] container"
  exec docker run --rm --gpus all --network host \
       -v "$(dirname "$MODEL_GGUF")":/models \
       spark-coding-agent-lab/ds4 -m "/models/$(basename "$MODEL_GGUF")"
fi
