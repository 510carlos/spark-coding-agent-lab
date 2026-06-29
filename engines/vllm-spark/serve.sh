#!/usr/bin/env bash
# Start vLLM on the GB10 sm_121 image. Defaults to Gemma-4-26B (NVFP4), the
# model proven to serve + batch on the Spark. Edit IMAGE/MODEL_DIR as needed.
set -euo pipefail
IMAGE="${VLLM_IMAGE:-ghcr.io/bjk110/vllm-spark:v022-d568-ngc2605-tx5102-vllm022}"
MODEL_DIR="${VLLM_MODEL_DIR:-/models/m}"   # host path to the NVFP4 checkpoint
NAME="${VLLM_SERVED_NAME:-gemma-26b}"

# reuse an existing container if present, else create one
if docker ps -a --format '{{.Names}}' | grep -qx vllm-spark; then
  exec docker start -a vllm-spark
fi
exec docker run --name vllm-spark --rm --gpus all --network host \
  -v "$(dirname "$MODEL_DIR")":/models \
  "$IMAGE" \
  vllm serve "$MODEL_DIR" --served-model-name "$NAME" \
    --max-model-len 65536 --gpu-memory-utilization 0.55 --trust-remote-code \
    --host 0.0.0.0 --port 8000 \
    --enable-auto-tool-choice --tool-call-parser gemma4 --enforce-eager
