# z840-workstation

Reproducible, idempotent build of an HP Z840 (2× E5-2680 v3, 128 GB, RTX 3060 12 GB, 4× 1 TB SSD) running Ubuntu 26.04 LTS:
secure + private by default, ZFS data pool, automated backups/updates, KVM virtualization, local AI, and an AI governance/security lab.

| Script | Purpose |
|---|---|
| `00-preflight.sh` | Read-only hardware/disk/SMART/GPU checks |
| `10-zfs.sh` | Encrypted raidz1 pool `tank` on the 3 blank SSDs, datasets, scrubs, ARC cap |
| `20-backups.sh` | sanoid snapshots + nightly encrypted restic backups, SMART monitoring |
| `30-updates-security.sh` | Unattended security/updates, sysctl hardening, UFW, DoT DNS, telemetry off, auditd/fail2ban |
| `40-office-dev-virt.sh` | Dev toolchain, Docker, KVM/libvirt on ZFS, Cockpit |
| `50-ai.sh` | NVIDIA container toolkit, Ollama + Open WebUI (localhost only) |
| `60-ai-security-lab.sh` | garak, PyRIT, Presidio, llm-guard, promptfoo (as normal user) |

Run in order with `sudo ./scripts/NN-name.sh` (60 without sudo). Design decisions: see `docs/DESIGN.md`.
