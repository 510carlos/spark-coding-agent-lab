#!/usr/bin/env bash
# Fetch model weights listed in MANIFEST.md into models/weights/ (gitignored).
# Usage: ./models/fetch.sh {ds4|ds4-mtp}
#   Ollama / vLLM models are fetched by their own tools (see MANIFEST.md).
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)/weights"; mkdir -p "$DIR"
command -v huggingface-cli >/dev/null || pip install -q huggingface_hub[cli]

case "${1:-}" in
  ds4)
    huggingface-cli download "$DS4_HF_REPO" \
      "DeepSeek-V4-Flash-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8-chat-v2-imatrix.gguf" \
      --local-dir "$DIR"
    ln -sf "$DIR/DeepSeek-V4-Flash-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8-chat-v2-imatrix.gguf" \
           "$DIR/deepseek-v4-flash.gguf" ;;
  ds4-mtp)
    huggingface-cli download "$DS4_HF_REPO" \
      "DeepSeek-V4-Flash-MTP-Q4K-Q8_0-F32.gguf" --local-dir "$DIR" ;;
  *) echo "usage: fetch.sh {ds4|ds4-mtp}  (set DS4_HF_REPO to the GGUF repo id)"; exit 2;;
esac
echo "[fetch] done -> $DIR"
