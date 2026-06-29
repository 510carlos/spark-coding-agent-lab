# Model manifest

Weights are **fetched on the host, never baked into images or committed** (size +
license). Pick the model(s) for the engine you want to run.

| Engine | Model | Source | On-disk | Fetch |
|---|---|---|---|---|
| DS4 | DeepSeek V4 Flash (selective Q2 GGUF) | HF GGUF: `DeepSeek-V4-Flash-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8-chat-v2-imatrix.gguf` | ~81 GiB | `./models/fetch.sh ds4` |
| DS4 | DeepSeek V4 Flash MTP draft head (optional) | HF GGUF: `DeepSeek-V4-Flash-MTP-Q4K-Q8_0-F32.gguf` | ~3.6 GiB | `./models/fetch.sh ds4-mtp` |
| Ollama | qwen3-coder-next (80B-A3B, GGUF) | `ollama pull qwen3-coder-next` | ~51 GB | `ollama pull qwen3-coder-next` |
| Ollama | qwen3.6-35B-A3B (GGUF) | `ollama pull qwen3.6:35b` | ~23 GB | `ollama pull qwen3.6:35b` |
| Ollama | Ornith-1.0-35B (GGUF) | `hf.co/deepreinforce-ai/Ornith-1.0-35B-GGUF` | ~21 GB | `ollama pull hf.co/deepreinforce-ai/Ornith-1.0-35B-GGUF` |
| vLLM | Gemma-4-26B-A4B (NVFP4) | HF: see engines/vllm-spark/README.md | ~16.5 GB | per vLLM README |

## Notes
- Place GGUFs under `models/weights/` (gitignored). DS4 expects the path passed
  via `engines/ds4/serve.sh`.
- The DS4 Q2 build is the only thing that fits a 284B model in 128 GB — full
  BF16 would be ~568 GB. Don't try to pull the full weights on a Spark.
- `fetch.sh` is a thin wrapper around `huggingface-cli download`; set `HF_TOKEN`
  if the repo is gated.
