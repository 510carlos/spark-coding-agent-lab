# spark-coding-agent-lab — one-command surface for reproducing the benchmark grid.
#
#   make doctor                                   # check the 3 host facts
#   make fetch MODEL=ds4                           # one-time weights
#   make bench ENGINE=ds4 HARNESS=claude-code      # reclaim → run → score
#   make bench ENGINE=ds4 HARNESS=claude-code EVICT=1 RESTORE=1   # evict a foreign engine, then restore it
#
# ENGINE  ∈ {ds4, vllm, ollama}      HARNESS ∈ {claude-code, opencode, qwen-code, minion}

ENGINE  ?= ollama
HARNESS ?= opencode
MODEL   ?=
NEED    ?= 90
COMPOSE  = docker compose
EVICT_FLAG   = $(if $(EVICT),--evict,)
RESTORE_FLAG = $(if $(RESTORE),--restore-after,)

.PHONY: doctor fetch build free-gpu bench attach restore down clean matrix

doctor:
	@echo "== host facts (everything else is in containers) =="
	@nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null \
	  || { echo "✗ no NVIDIA driver — install ≥580"; exit 1; }
	@docker info >/dev/null 2>&1 && echo "✓ docker" || { echo "✗ docker not running"; exit 1; }
	@docker run --rm --gpus all nvidia/cuda:13.0.0-base-ubuntu24.04 nvidia-smi -L >/dev/null 2>&1 \
	  && echo "✓ nvidia-container-toolkit (--gpus all works)" \
	  || { echo "✗ nvidia-container-toolkit missing — containers can't see the GPU"; exit 1; }
	@df -BG --output=avail . | tail -1 | awk '{g=$$1+0; print (g>=150)?"✓ disk "$$1" free":"✗ need ≥150G free ("$$1")"}'
	@echo "host OK — everything else ships in images."

fetch:
	@DS4_HF_REPO=$(DS4_HF_REPO) ./models/fetch.sh $(MODEL)

build:
	$(COMPOSE) --profile $(ENGINE) --profile bench build

free-gpu:
	@./free-gpu --need $(NEED) --keep $(ENGINE) $(EVICT_FLAG) $(RESTORE_FLAG)

# the one command: reclaim the GPU, bring up exactly one engine, run the harness, score.
bench: free-gpu
	@echo "== starting engine: $(ENGINE) =="
	$(COMPOSE) --profile $(ENGINE) up -d --wait
	@echo "== running $(HARNESS) × $(ENGINE) =="
	-$(COMPOSE) run --rm -e ENGINE=$(ENGINE) -e HARNESS=$(HARNESS) -e MODEL=$(MODEL) bench
	-$(COMPOSE) --profile $(ENGINE) down    # free the engine BEFORE restoring a foreign one (avoid OOM)
	@$(MAKE) --no-print-directory restore

# attach mode: skip launch, just point the bench at an already-running engine
attach:
	-$(COMPOSE) run --rm -e ENGINE=$(ENGINE) -e HARNESS=$(HARNESS) -e MODEL=$(MODEL) bench

# restart any foreign engines free-gpu evicted with RESTORE=1
restore:
	@if [ -s /tmp/spark-coding-agent-lab.evicted ]; then \
	  echo "== restoring evicted engines =="; \
	  awk '$$1=="container"{print $$2}' /tmp/spark-coding-agent-lab.evicted | xargs -r -n1 docker start; \
	  : > /tmp/spark-coding-agent-lab.evicted; fi

# run the whole matrix for one engine
matrix:
	@for h in opencode claude-code qwen-code; do \
	  $(MAKE) --no-print-directory bench ENGINE=$(ENGINE) HARNESS=$$h MODEL=$(MODEL); done

down:
	$(COMPOSE) --profile ds4 --profile vllm --profile ollama --profile bench down

clean: down
	$(COMPOSE) down -v
