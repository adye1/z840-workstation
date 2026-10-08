# Design decisions
- **Root stays LUKS + LVM + ext4** (installed that way); ZFS holds data/VMs/AI. Root is protected by restic, not ZFS snapshots.
- **ZFS raidz1 on 3 disks** (~1.8 TB usable): survives one disk failure. Native AES-256-GCM encryption; key on the LUKS root so the pool unlocks automatically and is useless if drives are removed.
- **ZFS is not a backup.** Snapshots (sanoid) cover accidents; restic covers the OS; an offsite target (`/etc/restic/offsite.env`) covers theft/fire/ransomware.
- **Updates**: security+updates auto-applied, no forced reboot, snaps refresh Saturdays 03:00-05:00, Livepatch via Ubuntu Pro.
- **Privacy**: telemetry/apport off, DNS-over-TLS, Ollama/Open WebUI bound to 127.0.0.1, no cloud model calls by default.
- **Known trade-offs**: ARC capped at 16 GB; single GPU is used for AI (no VFIO passthrough); NVIDIA driver auto-updates can require reboot.
