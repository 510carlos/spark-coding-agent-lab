# Harnesses

Each `run-<harness>.sh` takes the same args from `run.sh`:
`WORKDIR MODEL OPENAI_URL ANTHROPIC_URL TASK` — so any harness can be pointed at
any engine, because every engine exposes an OpenAI- and/or Anthropic-compatible
endpoint.

| Harness | Wiring | Endpoint used |
|---|---|---|
| **claude-code** | `ANTHROPIC_BASE_URL` + dummy token, `claude -p … --dangerously-skip-permissions` | Anthropic `/v1/messages` |
| **opencode** | generated `~/.config/opencode/opencode.json` custom provider | OpenAI `/v1` |
| **qwen-code** | `OPENAI_BASE_URL` / `OPENAI_MODEL`, `qwen --approval-mode yolo` | OpenAI `/v1` |
| **minion** | tmux + `bench/driver.py`, `MINION_BASE_URL` | OpenAI `/v1` |

Notes:
- Claude Code and Ollama/DS4 both speak the Anthropic Messages API — that is why
  Claude Code can drive a local model unchanged.
- `--dangerously-skip-permissions` / `--approval-mode yolo` are intended for
  *unattended benchmark runs in a throwaway repository only*; do not use them in
  real workflows.
- **minion is included for reference but not recommended:** it does not reliably
  self-terminate (it continued exploring after the tests passed and ran to the
  timeout in every grid run). It is excluded from the headline results and from
  `make matrix`.
- **Known incompatibility:** Ornith-1.0-35B via **claude-code** returns an HTTP 400
  because its GGUF chat template requires the system message to come first, which
  the Anthropic `/v1/messages` request (translated by Ollama) violates. The same
  model works through the OpenAI path (opencode, qwen-code).
- The bench-client image runs as a **non-root user** — Claude Code refuses
  `--dangerously-skip-permissions` when run as root.
