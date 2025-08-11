#!/bin/bash
# Set Hugging Face cache directory
echo 'export HF_HOME=/media/data_2/hf_home' >> ~/.bashrc

# Set uv package manager cache directory
echo 'export UV_CACHE_DIR=/media/data_2/docker/uv_containers' >> ~/.bashrc

# Apply changes immediately
source ~/.bashrc
