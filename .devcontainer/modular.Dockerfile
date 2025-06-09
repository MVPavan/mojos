FROM modular/max-nvidia-full:nightly as mod

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
        git && \
    rm -rf /var/lib/apt/lists/*

RUN curl -LsSf https://astral.sh/uv/install.sh | sh

ENTRYPOINT ["/bin/bash"]