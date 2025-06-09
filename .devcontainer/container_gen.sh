#!/bin/bash

# use env_template.txt and create a .env with all those variables
# Load environment variables from .env
source .env

# Generate compose file
cat <<EOF > $COMPOSE_FILE_NAME
services:
  $SERVICE_NAME:
    build:
      context: ./
      dockerfile: $DOCKERFILE_NAME
    image: $IMAGE_NAME
    container_name: $CONTAINER_NAME
    network_mode: host
    environment:
      - HF_HOME=$HF_HOME
      - UV_CACHE_DIR
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - type: bind
        source: $CODE
        target: $CODE
      - type: bind
        source: $DATASET
        target: $DATASET
      - type: bind
        source: $CONDA_CACHE
        target: $CONDA_CACHE
      - type: bind
        source: $HF_HOME
        target: $HF_HOME
      - type: bind
        source: $UV_CACHE_DIR
        target: $UV_CACHE_DIR
      
    ulimits:
      memlock:
        soft: -1
        hard: -1
      stack:
        soft: 67108864
        hard: 67108864
    security_opt:
      - apparmor:unconfined
    ipc: host
    
    stdin_open: true 
    tty: true

    # Uncomment if below doesnt work
    # runtime: nvidia
    # default choice
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
EOF

echo "$COMPOSE_FILE_NAME generated."


# Generate .condarc
cat <<EOF > dev_entrypoint.sh
#!/bin/bash
# Set Hugging Face cache directory
echo 'export HF_HOME=$HF_HOME' >> ~/.bashrc

# Set uv package manager cache directory
echo 'export UV_CACHE_DIR=$UV_CACHE_DIR' >> ~/.bashrc

# Apply changes immediately
source ~/.bashrc
EOF

echo "dev_entrypoint generated."

# Generate devcontainer.json
cat <<EOF > devcontainer.json
{
    "name": "$DEVCONTAINER_NAME",
    "dockerComposeFile": "$COMPOSE_FILE_NAME",
    "service": "$SERVICE_NAME",
    "workspaceFolder": "$CODE",
    "customizations": {
        "vscode": {
            "settings": {
                "terminal.integrated.shell.linux": "/bin/bash"
            },
            "extensions": [
                "sugatoray.vscode-git-extension-pack",
                "franneck94.vscode-python-dev-extension-pack",
                "franneck94.vscode-coding-tools-extension-pack",
                "gruntfuggly.todo-tree",
                "streetsidesoftware.code-spell-checker",
                "oderwat.indent-rainbow",
                "mechatroner.rainbow-csv",
                "moshfeu.compare-folders",
                "mikestead.dotenv",
                "ms-toolsai.jupyter",
                "yahyabatulu.vscode-markdown-alert",
                "tomoki1207.pdf"
            ]
        }
    },
    "remoteUser": "root",
    "shutdownAction": "none",
    "postCreateCommand": "/bin/bash .devcontainer/dev_entrypoint.sh"
}
EOF

echo "devcontainer.json generated."

# Generate .condarc
cat <<EOF > .condarc
envs_dirs:
  - $CONDA_CACHE/envs
  - /opt/conda/envs

pkgs_dirs:
  - $CONDA_CACHE/pkgs
  - /opt/conda/pkgs
EOF

echo ".condarc generated."
