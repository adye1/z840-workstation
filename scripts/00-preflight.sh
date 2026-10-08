#!/usr/bin/env bash
# Read-only checks. Safe to run any time.
source "$(dirname "$0")/lib.sh"
log "OS / kernel";  lsb_release -ds; uname -r
log "Secure Boot";  mokutil --sb-state || true
log "Virtualization (VT-x / IOMMU)"; grep -c -w vmx /proc/cpuinfo | xargs echo "vmx threads:"; dmesg | grep -iE 'DMAR|IOMMU' | head -3 || true
log "Root encryption"; lsblk -o NAME,TYPE,FSTYPE,MOUNTPOINT | grep -E 'crypt|/$' || echo "WARNING: root not on LUKS"
log "Candidate ZFS disks (must be blank)"
for d in sdb sdc sdd; do echo "-- /dev/$d"; wipefs -n "/dev/$d" || true; lsblk -no NAME,SIZE,MOUNTPOINT "/dev/$d"; done
log "SMART health"; apt_install smartmontools >/dev/null; for d in sda sdb sdc sdd; do smartctl -H "/dev/$d" | grep -i result || true; done
log "GPU"; nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv
