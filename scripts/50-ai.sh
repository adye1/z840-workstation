#!/usr/bin/env bash
# Local AI stack sized for RTX 3060 12GB + 128GB RAM: Ollama (GPU) + Open WebUI, NVIDIA container toolkit, uv/Jupyter.
source "$(dirname "$0")/lib.sh"
nvidia-smi >/dev/null || { echo "NVIDIA driver not working"; exit 1; }
if ! command -v nvidia-ctk &>/dev/null; then
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit.gpg
  curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
    | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit.gpg] https://#' > /etc/apt/sources.list.d/nvidia-container-toolkit.list
  apt-get update && apt_install nvidia-container-toolkit
fi
nvidia-ctk runtime configure --runtime=docker && systemctl restart docker
# Models live on ZFS
MODELS=/tank/ai/models; [[ -d $MODELS ]] || MODELS="$TARGET_HOME/ai-models"; install -d -o "$TARGET_USER" "$MODELS"
# Ollama: bound to localhost only (privacy). Installer is vendor script - read it first if you prefer.
command -v ollama &>/dev/null || { curl -fsSL https://ollama.com/install.sh -o /root/ollama-install.sh && sh /root/ollama-install.sh; }
install -d /etc/systemd/system/ollama.service.d
cat > /etc/systemd/system/ollama.service.d/override.conf <<C
[Service]
Environment="OLLAMA_HOST=127.0.0.1:11434"
Environment="OLLAMA_MODELS=$MODELS/ollama"
Environment="OLLAMA_KEEP_ALIVE=15m"
Environment="OLLAMA_FLASH_ATTENTION=1"
C
install -d -o ollama -g ollama "$MODELS/ollama" 2>/dev/null || install -d "$MODELS/ollama"
systemctl daemon-reload; systemctl enable --now ollama; systemctl restart ollama
# Open WebUI, localhost-only, no telemetry
docker rm -f open-webui &>/dev/null || true
docker run -d --name open-webui --restart unless-stopped --network host \
  -e OLLAMA_BASE_URL=http://127.0.0.1:11434 -e PORT=3000 -e HOST=127.0.0.1 -e ANONYMIZED_TELEMETRY=false -e SCARF_NO_ANALYTICS=true -e DO_NOT_TRACK=true \
  -v open-webui:/app/backend/data ghcr.io/open-webui/open-webui:main
sudo -u "$TARGET_USER" -H bash -c 'ollama pull llama3.1:8b && ollama pull qwen2.5-coder:14b'
log "12GB VRAM guide: 7-14B Q4 fully on GPU; 32B Q4 runs partly offloaded to 128GB RAM (slower); 70B runs CPU-heavy."
log "Open WebUI: http://127.0.0.1:3000   Ollama API: http://127.0.0.1:11434"
