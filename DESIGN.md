# Design — eliminating the setup overhead

## The problem this solves
> "I want to evaluate local coding agents on a DGX Spark, but standing up the
> full stack by hand is slow and error-prone."

Reproducing this stack manually means installing uv, Node, four agent CLIs,
Docker, the NVIDIA Container Toolkit, tmux, and huggingface-cli; building DS4 from
source; fetching ~80 GB of weights; and manually stopping whatever already holds
the GPU so a second large model doesn't exhaust unified memory and lock the host.
This lab reduces all of that to a single command.

**The promise:** three host facts you can't containerize away, then one command.

```bash
make doctor                       # checks the 3 host facts, nothing else
make fetch  MODEL=ds4             # one-time weights pull into ./weights
make bench  ENGINE=ds4 HARNESS=claude-code
```

## The 3 irreducible host facts (everything else is in a container)
1. **NVIDIA driver ≥ 580** — lives in the host kernel; images bring CUDA *userland*, not the driver.
2. **Docker + `nvidia-container-toolkit`** — so containers get `--gpus all`.
3. **~150 GB free disk** for weights.

`make doctor` verifies exactly these and nothing more. Everything else — uv,
pytest, tmux, Claude Code / OpenCode / Qwen Code / minion, the engine builds —
ships inside images.

## Architecture: compose, one bridge network
```
        bench-client (image: uv, pytest, tmux, all 4 harness CLIs, bench/)
                       │  OpenAI/Anthropic over the docker network
        ┌──────────────┼───────────────┐
   ds4 (profile)   vllm (profile)   ollama (profile)     ← exactly ONE up
   :8080           :8000            :11434
        └──── ./weights:/models (volume) ───┘   ./results (volume)
```
- **One image per engine**, behind a compose **profile** so only the chosen one starts.
- **One bench-client image** holding all four harnesses; it points
  `ANTHROPIC_BASE_URL` / `OPENAI_BASE_URL` at the engine's service name.
- **Pre-built on GHCR** (ds4, bench-client) so cloners pull instead of building;
  build-from-source is a fallback target. (vLLM uses the published GB10 image;
  Ollama is the official image.)

## One engine at a time — enforced, not hoped
A 284 B GGUF (~81 GB) and an 80 B coder (~51 GB) can't co-reside in 128 GB.
Running two large models at once exhausts unified memory and can hard-lock the
host. So every launch runs **`free-gpu`** first.

### `free-gpu` reclaimer (grounded in what actually works on GB10)
- **Detect** with `nvidia-smi --query-compute-apps=pid,process_name,used_memory
  --format=csv,noheader`. *Verified:* this reports real per-process GPU memory on
  GB10 (e.g. `VLLM::EngineCore … 64075 MiB`). **Do NOT use `ps` RSS** — that same
  64 GB process shows only 3.9 GB RSS because unified-memory GPU allocations
  aren't in RSS. (`lsof /dev/nvidia*` also came back empty here — unreliable.)
- **Classify** each holder > 2 GB:
  - lab-managed engine (label `spark-coding-agent-lab=1`) → stop freely.
  - foreign engine (your own vLLM/Ollama) → **don't auto-kill**; abort + report,
    require `--evict`.
  - protected (Xorg, gnome-shell, sshd, dockerd, the orchestrator) → never touch.
  - unknown big holder → **abort with a report**, don't blind-kill.
- **Gate** on `free` *available* ≥ model size + margin (DS4 ⇒ ≥ ~90 GB) before launch.
- **Allowlist-to-kill:** we only ever reap things we recognize. On a unified-memory
  box the wrong kill takes down your desktop or SSH.

## "I already have vLLM running" — attach / evict / restore
| You want… | Behavior |
|---|---|
| the **same** model your running engine serves | **attach** — `GET /v1/models` matches → point bench-client at it, stop nothing |
| a **different** engine, no flags | **abort + report** ("a foreign vLLM container holds the GPU; pass `--evict`") |
| different engine, `--evict --restore-after` | record it → stop it → bench → **restart it** (your other service self-heals) |

Principle: **never evict a foreign engine without consent, always offer to put it back.**

## Switching the model — vLLM vs Ollama are different beasts
- **vLLM / DS4** serve *one model per process*. "Switch model" = the orchestrator
  **restarts the engine container** with a new `--model`/mount (~minutes). No API
  hot-swap.
- **Ollama** is a *model manager*. "Switch model" = **change the `model` field in
  the request**; it loads/unloads on demand (seconds). No restart.

## Ollama networking — the loopback trap (verified)
Default `ollama serve` binds **`127.0.0.1:11434`**, so a container gets
**connection refused** (we reproduced: HTTP 000). Fixes, pick one:
1. **Containerize Ollama** (official `ollama/ollama` image) → pure container↔container. *(recommended default)*
2. `OLLAMA_HOST=0.0.0.0:11434` on the host Ollama → reach via `host.docker.internal` (host-gateway).
3. run bench-client with `--network host` → sees `127.0.0.1:11434` directly.

## What this is honestly NOT
Reproducible **on a GB10-class DGX Spark**, not "anywhere." Results are
GB10-specific. You still download the weights once. That's the point — it's a
*hardware demo* that happens to be turn-key, not a cross-platform abstraction.
