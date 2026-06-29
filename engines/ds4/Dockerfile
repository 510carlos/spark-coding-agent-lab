# DS4 — DeepSeek V4 Flash inference server, built for DGX Spark (GB10 / sm_121).
# Build:  docker build -t spark-coding-agent-lab/ds4 engines/ds4
# Run:    via engines/ds4/serve.sh (mounts the GGUF from models/weights)
FROM nvidia/cuda:13.0.0-devel-ubuntu24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
      git build-essential ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt
RUN git clone https://github.com/antirez/ds4 && \
    cd ds4 && make cuda-spark      # GB10/sm_121 CUDA target

# weights are mounted at runtime, never baked in
ENV DS4_MODEL=/models/deepseek-v4-flash.gguf
EXPOSE 8080
WORKDIR /opt/ds4
ENTRYPOINT ["./ds4-server", "--cuda", "--host", "0.0.0.0", "--port", "8080", "--ctx", "131072", "--cors"]
CMD ["-m", "/models/deepseek-v4-flash.gguf"]
