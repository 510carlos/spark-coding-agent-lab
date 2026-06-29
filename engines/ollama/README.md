# Ollama engine

Ollama serves both an **OpenAI-compatible** endpoint (`/v1`) and an
**Anthropic-compatible** endpoint (`/v1/messages`) on port **11434** — so it
works with every harness here, including Claude Code.

```bash
ollama serve &                     # start the daemon
ollama pull qwen3-coder-next       # ~51 GB GGUF (the fast 80B coder lane)
```

`run.sh --engine ollama` will start the daemon and warm the model for you.
Default model: `qwen3-coder-next:latest`. Override with `--model`.

Notes:
- Ollama is `mmap`-backed, so it loads large GGUFs the unified-memory-safe way
  (unlike eager allocators). Still: **one engine at a time** — `run.sh` stops
  DS4 / vLLM before starting Ollama.
- Warm tok/s observed on the Spark: ~33 tok/s for qwen3-coder-next.
