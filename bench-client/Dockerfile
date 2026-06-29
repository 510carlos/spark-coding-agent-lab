# bench-client — one image with all four coding-agent harnesses + the bench.
# Build context is the REPO ROOT (so it can COPY bench/ and harnesses/):
#   docker build -t spark-coding-agent-lab-bench -f bench-client/Dockerfile .
FROM node:20-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 python3-venv python3-pip tmux git curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# uv (used by the bench/minion to run pytest in throwaway envs) + pytest
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    cp /root/.local/bin/uv /root/.local/bin/uvx /usr/local/bin/ && \
    pip install --break-system-packages pytest

# the four harnesses
RUN npm install -g \
      @anthropic-ai/claude-code \
      opencode-ai \
      @qwen-code/qwen-code && \
    git clone --depth 1 https://github.com/Sentdex/minion /opt/minion

# bake the bench + harness wiring in (self-contained for GHCR; override via mount if desired)
COPY bench/      /lab/seed/bench/
COPY harnesses/  /lab/harnesses/
COPY bench-client/entrypoint.sh /lab/entrypoint.sh
RUN chmod +x /lab/entrypoint.sh /lab/harnesses/*.sh

# Claude Code refuses --dangerously-skip-permissions as root, so run as the
# image's non-root `node` user (uid 1000 → matches the host, so mounted
# ./results writes succeed).
RUN chown -R node:node /lab
USER node
ENV HOME=/home/node
WORKDIR /lab
ENTRYPOINT ["/lab/entrypoint.sh"]
