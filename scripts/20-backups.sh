#!/usr/bin/env bash
# sanoid: ZFS snapshots.  restic: encrypted, deduplicated backups of / and /home into tank/backup (+ optional offsite).
# Optional offsite: put e.g. RESTIC_OFFSITE=sftp:user@host:/path (or b2:bucket:path) in /etc/restic/offsite.env
source "$(dirname "$0")/lib.sh"
apt_install sanoid restic smartmontools
install -d /etc/sanoid
cat > /etc/sanoid/sanoid.conf <<'C'
[tank/data]
  use_template = prod
  recursive = yes
[tank/projects]
  use_template = prod
  recursive = yes
[tank/vm]
  use_template = prod
  recursive = yes
[tank/ai/datasets]
  use_template = prod
[tank/backup]
  use_template = prod
[template_prod]
  frequently = 0
  hourly = 24
  daily = 30
  weekly = 8
  monthly = 12
  autosnap = yes
  autoprune = yes
C
systemctl enable --now sanoid.timer
install -d -m 700 /etc/restic
[[ -f /etc/restic/password ]] || { head -c 32 /dev/urandom | base64 > /etc/restic/password; chmod 400 /etc/restic/password; }
export RESTIC_REPOSITORY=/tank/backup/restic RESTIC_PASSWORD_FILE=/etc/restic/password
restic cat config &>/dev/null || restic init
cat > /usr/local/sbin/restic-backup <<'S'
#!/usr/bin/env bash
set -euo pipefail
export RESTIC_PASSWORD_FILE=/etc/restic/password
run() { restic -r "$1" backup / --one-file-system --exclude-caches \
  --exclude /tank --exclude /var/lib/docker --exclude /var/lib/libvirt/images --exclude /var/cache \
  --exclude '/home/*/.cache' --exclude '/home/*/.ollama' --exclude '/var/lib/snapd' --exclude /swap.img \
  --tag auto --host "$(hostname)"; restic -r "$1" forget --keep-daily 14 --keep-weekly 8 --keep-monthly 12 --keep-yearly 2 --prune; }
run /tank/backup/restic
# /boot and /boot/efi are separate mounts: include explicitly
restic -r /tank/backup/restic backup /boot /boot/efi --tag auto-boot --host "$(hostname)"
if [[ -f /etc/restic/offsite.env ]]; then . /etc/restic/offsite.env; run "$RESTIC_OFFSITE"; fi
# monthly integrity check of 5% of data
[[ $(date +%d) == 01 ]] && restic -r /tank/backup/restic check --read-data-subset=5% || true
S
chmod 750 /usr/local/sbin/restic-backup
cat > /etc/systemd/system/restic-backup.service <<'U'
[Unit]
Description=Restic backup
After=local-fs.target zfs-mount.service
[Service]
Type=oneshot
Environment=XDG_CACHE_HOME=/var/cache/restic
Nice=10
IOSchedulingClass=idle
ExecStart=/usr/local/sbin/restic-backup
U
cat > /etc/systemd/system/restic-backup.timer <<'U'
[Unit]
Description=Nightly restic backup
[Timer]
OnCalendar=*-*-* 01:30
Persistent=true
RandomizedDelaySec=15m
[Install]
WantedBy=timers.target
U
cat > /etc/smartd.conf <<'S'
DEVICESCAN -a -o on -S on -n standby,q -s (S/../.././02|L/../01/./03) -m root -M exec /usr/share/smartmontools/smartd-runner
S
systemctl daemon-reload; systemctl enable --now restic-backup.timer smartmontools
log "Backups armed. COPY /etc/restic/password OFF-MACHINE. Test restore: restic -r /tank/backup/restic restore latest --target /tmp/r --include /etc/hostname"
log "3-2-1 note: tank/backup lives on the same box. Configure /etc/restic/offsite.env for a true offsite copy."
