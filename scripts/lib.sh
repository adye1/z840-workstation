#!/usr/bin/env bash
# Shared helpers. Sourced by every numbered script.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run with sudo: sudo $0" >&2; exit 1; }
export DEBIAN_FRONTEND=noninteractive
log() { printf '\033[1;34m==> %s\033[0m\n' "$*"; }
apt_install() { apt-get install -y --no-install-recommends "$@"; }
# The login user who invoked sudo (never root)
TARGET_USER="${SUDO_USER:?run via sudo from your normal account}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
