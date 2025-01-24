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
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - type: bind
        source: $CODE
        target: $CODE
      - type: bind
        source: $DATASET
        target: $DATASET
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
    "shutdownAction": "none"
}
EOF

echo "devcontainer.json generated."

# Generate .condarc
cat <<EOF > .condarc
envs_dirs:
  - $CONDA/envs
  - /opt/conda/envs

pkgs_dirs:
  - $CONDA/pkgs
  - /opt/conda/pkgs
EOF

echo ".condarc generated."
