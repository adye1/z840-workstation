#!/usr/bin/env bash
# Creates encrypted raidz1 pool "tank" from sdb/sdc/sdd.  DESTRUCTIVE to those 3 disks only.
# Override layout: LAYOUT=raidz1 (default, ~1.8TB usable, survives 1 disk loss)
#                  LAYOUT=mirror-spare (1 TB usable ×1 mirror + hot spare)  LAYOUT=stripe (2.7TB, NO redundancy)
source "$(dirname "$0")/lib.sh"
DISKS=(sdb sdc sdd); LAYOUT="${LAYOUT:-raidz1}"; POOL=tank
ROOT_DISK="$(lsblk -no PKNAME "$(findmnt -no SOURCE /boot)" | head -1)"
apt_install zfsutils-linux zfs-zed
zpool list "$POOL" &>/dev/null && { log "Pool $POOL already exists - nothing to do"; zpool status "$POOL"; exit 0; }
IDS=()
for d in "${DISKS[@]}"; do
  [[ "$d" != "$ROOT_DISK" ]] || { echo "refusing: $d is the boot disk" >&2; exit 1; }
  [[ -z "$(lsblk -no MOUNTPOINT "/dev/$d" | tr -d '[:space:]')" ]] || { echo "refusing: /dev/$d is mounted" >&2; exit 1; }
  [[ -z "$(wipefs -n "/dev/$d")" ]] || { echo "refusing: /dev/$d has existing signatures (wipefs -a it yourself if intended)" >&2; exit 1; }
  IDS+=("$(ls -l /dev/disk/by-id | awk -v d="$d" '$NF ~ "/"d"$" && $9 ~ /^(ata|wwn)-/ && $9 !~ /part/ {print "/dev/disk/by-id/"$9}' | grep '^/dev/disk/by-id/ata-' | head -1)")
done
log "Will create '$POOL' ($LAYOUT) on: ${IDS[*]}"
read -r -p "Type YES to destroy all data on these disks: " ok; [[ "$ok" == YES ]] || exit 1

# Encryption key lives on the LUKS-encrypted root -> pool auto-unlocks at boot, disks at rest are encrypted.
install -d -m 700 /etc/zfs/keys
[[ -f /etc/zfs/keys/$POOL.key ]] || { head -c 32 /dev/urandom > /etc/zfs/keys/$POOL.key; chmod 400 /etc/zfs/keys/$POOL.key; }
case "$LAYOUT" in
  raidz1)       VDEV=(raidz1 "${IDS[@]}") ;;
  mirror-spare) VDEV=(mirror "${IDS[0]}" "${IDS[1]}" spare "${IDS[2]}") ;;
  stripe)       VDEV=("${IDS[@]}") ;;
  *) echo "bad LAYOUT"; exit 1 ;;
esac
zpool create -o ashift=12 -o autotrim=on \
  -O compression=zstd -O atime=off -O relatime=on -O xattr=sa -O acltype=posixacl -O dnodesize=auto \
  -O normalization=formD -O mountpoint=/tank \
  -O encryption=aes-256-gcm -O keyformat=raw -O keylocation=file:///etc/zfs/keys/$POOL.key \
  "$POOL" "${VDEV[@]}"
zfs create -o recordsize=64K  "$POOL/vm"        # libvirt disk images
zfs create -o recordsize=1M   "$POOL/ai"        # model weights (large sequential files)
zfs create                    "$POOL/ai/models"
zfs create                    "$POOL/ai/datasets"
zfs create                    "$POOL/data"
zfs create                    "$POOL/projects"
zfs create -o compression=zstd-3 "$POOL/backup" # restic repo + local copy of configs
chown -R "$TARGET_USER:$TARGET_USER" /tank/{ai,data,projects}
# ARC cap: leave RAM for VMs + AI (128GB host)
echo "options zfs zfs_arc_max=$((16*1024**3))" > /etc/modprobe.d/zfs-arc.conf; update-initramfs -u
# Load the encryption key at boot (stock zfs-mount runs "zfs mount -a" without -l, leaving the pool locked)
install -d /etc/systemd/system/zfs-mount.service.d
printf '[Service]\nExecStart=\nExecStart=/usr/sbin/zfs mount -a -l\n' > /etc/systemd/system/zfs-mount.service.d/load-key.conf
systemctl daemon-reload
# Scrub monthly, TRIM weekly, ZED alerts to root mail/journal
systemctl enable --now zfs-zed
cat > /etc/systemd/system/zfs-scrub@.service <<'U'
[Unit]
Description=ZFS scrub of %i
[Service]
Type=oneshot
ExecStart=/usr/sbin/zpool scrub %i
U
cat > /etc/systemd/system/zfs-scrub@.timer <<'U'
[Unit]
Description=Monthly ZFS scrub of %i
[Timer]
OnCalendar=*-*-01 02:00
Persistent=true
RandomizedDelaySec=1h
[Install]
WantedBy=timers.target
U
systemctl daemon-reload; systemctl enable --now zfs-scrub@$POOL.timer
log "BACK UP /etc/zfs/keys/$POOL.key OFF-MACHINE (password manager). Losing it = losing the pool."
zpool status "$POOL"; zfs list -r "$POOL"
