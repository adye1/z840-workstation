#!/usr/bin/env bash
# Automated updates + baseline hardening + privacy. Conservative: nothing here locks you out.
source "$(dirname "$0")/lib.sh"
apt_install unattended-upgrades apt-listchanges needrestart apparmor-utils auditd fail2ban ufw rkhunter lynis
cat > /etc/apt/apt.conf.d/52z840-updates <<'C'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
Unattended-Upgrade::Origins-Pattern { "origin=Ubuntu,codename=${distro_codename}-security"; "origin=Ubuntu,codename=${distro_codename}-updates"; "origin=UbuntuESMApps,codename=${distro_codename}-apps-security"; "origin=UbuntuESM,codename=${distro_codename}-infra-security"; };
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";   // workstation: you reboot; needrestart handles services
Unattended-Upgrade::Mail "root";
C
sed -i 's/^#\?\$nrconf{restart}.*/$nrconf{restart} = '"'a'"';/' /etc/needrestart/needrestart.conf
snap set system refresh.timer=sat,03:00-05:00 refresh.retain=2
# Kernel / network hardening
cat > /etc/sysctl.d/60-z840-hardening.conf <<'C'
kernel.kptr_restrict=2
kernel.dmesg_restrict=1
kernel.unprivileged_bpf_disabled=1
net.core.bpf_jit_harden=2
kernel.yama.ptrace_scope=1
fs.protected_hardlinks=1
fs.protected_symlinks=1
fs.protected_fifos=2
fs.protected_regular=2
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.all.log_martians=1
net.ipv6.conf.all.accept_redirects=0
net.ipv4.tcp_syncookies=1
vm.swappiness=10
C
sysctl --system >/dev/null
# Firewall: default deny in; libvirt/docker manage their own bridges
ufw default deny incoming; ufw default allow outgoing; ufw --force enable
# DNS-over-TLS (privacy). Quad9 with fallback disabled would break captive portals, so opportunistic.
install -d /etc/systemd/resolved.conf.d
cat > /etc/systemd/resolved.conf.d/dot.conf <<'C'
[Resolve]
DNS=9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net
DNSOverTLS=opportunistic
DNSSEC=allow-downgrade
C
systemctl restart systemd-resolved
# Privacy: disable crash/usage telemetry
systemctl disable --now apport.service whoopsie.service 2>/dev/null || true
sed -i 's/^enabled=1/enabled=0/' /etc/default/apport 2>/dev/null || true
apt-get purge -y popularity-contest ubuntu-report whoopsie 2>/dev/null || true
ubuntu-report -f send no 2>/dev/null || true
# Auditing + brute-force protection
systemctl enable --now auditd fail2ban
[[ -f /etc/ssh/sshd_config ]] && cat > /etc/ssh/sshd_config.d/60-hardening.conf <<'C'
PasswordAuthentication no
PermitRootLogin no
C
log "SSH: password auth disabled ONLY IF sshd is installed. Ensure your key is in ~/.ssh/authorized_keys before enabling sshd."
log "Next (needs your account): sudo pro attach <token>  # free personal Ubuntu Pro: ESM, Livepatch, USG (CIS) hardening"
log "Audit baseline: sudo lynis audit system"
