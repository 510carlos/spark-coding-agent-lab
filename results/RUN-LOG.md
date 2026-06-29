# Results

Full **harness × model** grid for the planted-`--due`-bug task (13 tests, 2
failing at start). All models **warm-loaded** before timing, run **one at a
time** (no parallelism). minion excluded — it never self-terminates.

| Harness | DeepSeek-V4 284B (DS4) | qwen3-coder-80B | qwen3.6-35B | Ornith-1.0-35B |
|---|---|---|---|---|
| **OpenCode**   | 231 s · 13/13 | **20 s** · 13/13 | 43 s · 13/13 | 43 s · 13/13 |
| **Claude Code**| 172 s · 13/13 | 60 s · 13/13 | 43 s · 13/13 | ✗ template error |
| **Qwen Code**  | 181 s · 13/13 | 31 s · 13/13 | **24 s** · 13/13 | 43 s · 13/13 |

**Reads:**
- **11 of 12 cells fixed the bug correctly (13/13).** The model is not the bottleneck.
- The lone failure is an **endpoint/template incompatibility**, not a coding miss:
  Ornith-1.0-35B's GGUF chat template requires the system message first, which
  Claude Code's Anthropic `/v1/messages` request (translated by Ollama) violates
  → HTTP 400. The same model passes via the OpenAI path (OpenCode, Qwen Code).
- **Engine/model dominates wall-time, not harness.** DeepSeek-V4 284B is ~170–230 s
  across *every* harness (it runs at ~15 tok/s); the small/mid coders are 20–60 s.
- **qwen3.6-35B-A3B (warm) is the speed standout** (24–43 s) — matches or beats the
  80B. (Its earlier "105 s" was a cold 23 GB load.)
- Harness still matters *within* a model: on qwen3-coder-80B, OpenCode (20 s) was
  ~3× faster than Claude Code (60 s).

Reproduce any cell: `./run.sh --engine {ollama|ds4} --harness {opencode|claude-code|qwen-code} [--model NAME]`
