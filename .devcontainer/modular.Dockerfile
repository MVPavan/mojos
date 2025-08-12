<<<<<<< HEAD
# FROM modular/max-nvidia-full:nightly as mod
# FROM ubuntu:22.04
=======
# Docker containers not working for modular with GPU

# FROM modular/max-nvidia-full:nightly as mod
>>>>>>> afe5bb22984b54ae58a9094d6252f49d3562b5d4
FROM nvcr.io/nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04 as mod

RUN apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ffmpeg \
        gnutls-bin \
        gnutls-dev \
        libarchive-dev \
        libboost-all-dev \
        libgl1-mesa-glx \
        libsm6 \
        libxext6 \
        rapidjson-dev \
        wget \
        zlib1g-dev && \
    rm -rf /var/lib/apt/lists/*

RUN apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        curl \
        git \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

RUN update-ca-certificates

RUN curl -LsSf https://astral.sh/uv/install.sh | sh
RUN curl -fsSL https://pixi.sh/install.sh | sh

<<<<<<< HEAD

# Set Pixi's binary directory to PATH for all subsequent instructions and runtime
# This ensures pixi is available to all commands that run after this line.
ENV PATH="/root/.pixi/bin:$PATH"

# WORKDIR /workspaces/mojo-cs
# COPY . .
# RUN pixi init . -c https://conda.modular.com/max-nightly/ -c conda-forge && \
#     pixi add modular
=======
ENV PATH="/root/.pixi/bin:$PATH"
>>>>>>> afe5bb22984b54ae58a9094d6252f49d3562b5d4

ENTRYPOINT ["/bin/bash"]