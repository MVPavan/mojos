#!/bin/bash
# Set Hugging Face cache directory
echo 'export HF_HOME=/data/hf_home' >> ~/.bashrc

# Set uv package manager cache directory
echo 'export UV_CACHE_DIR=/data/docker/uv_containers' >> ~/.bashrc

# Apply changes immediately
source ~/.bashrc
