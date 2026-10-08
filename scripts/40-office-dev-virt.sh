#!/usr/bin/env bash
# Office + development + virtualization (KVM/libvirt + Cockpit).
source "$(dirname "$0")/lib.sh"
apt_install git gh build-essential curl wget jq ripgrep fd-find tmux htop btop neovim shellcheck \
  python3-venv python3-pip pipx pandoc docker.io docker-compose-v2 \
  qemu-system-x86 libvirt-daemon-system libvirt-clients virtinst virt-manager ovmf swtpm swtpm-tools bridge-utils \
  cockpit cockpit-machines cockpit-storaged cockpit-podman
usermod -aG docker,libvirt,kvm "$TARGET_USER"
snap list uv &>/dev/null || snap install astral-uv --classic
# KVM tuning for dual-socket Haswell: use hugepages-friendly THP, enable nested virt
echo "options kvm_intel nested=1" > /etc/modprobe.d/kvm-nested.conf
# libvirt storage pool on ZFS
if zfs list tank/vm &>/dev/null; then
  virsh pool-info zfsvm &>/dev/null || { virsh pool-define-as zfsvm dir --target /tank/vm && virsh pool-autostart zfsvm && virsh pool-start zfsvm; }
fi
systemctl enable --now libvirtd cockpit.socket
ufw allow from 192.168.0.0/16 to any port 9090 proto tcp comment 'cockpit LAN only' || true
log "Office: LibreOffice/OnlyOffice, Thunderbird, Brave, VS Code, Obsidian, Proton apps are already installed as snaps."
log "Log out/in for docker/libvirt group membership. Cockpit: https://localhost:9090"
