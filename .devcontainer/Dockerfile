FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Godot 4.3 (standard, non-.NET) + libs for headless runs and xvfb rendering
RUN apt-get update && apt-get install -y --no-install-recommends \
        unzip zip wget jq xvfb mesa-utils libgl1 libglu1-mesa \
        libvulkan1 mesa-vulkan-drivers \
        libasound2t64 libpulse0 libxcursor1 libxinerama1 libxrandr2 libxi6 \
        fontconfig ca-certificates python3 python3-pip \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip \
        -O /tmp/godot.zip \
    && unzip -q /tmp/godot.zip -d /tmp \
    && mv /tmp/Godot_v4.3-stable_linux.x86_64 /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot \
    && rm /tmp/godot.zip

# Pillow + numpy for the texture/audio asset helper scripts (tools/)
RUN pip3 install --break-system-packages pillow numpy

# Node.js 22 + Claude Code CLI for in-container agentic development
RUN wget -qO- https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g @anthropic-ai/claude-code
