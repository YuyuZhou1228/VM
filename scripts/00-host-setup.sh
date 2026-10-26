#!/usr/bin/env bash
# Install and configure the QEMU/KVM/libvirt stack on Ubuntu.
# Run this ONCE per host machine. Safe to re-run.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$(readlink -f "$0")")/lib.sh"

[[ ${EUID} -ne 0 ]] || die "Run as your normal user (the script calls sudo where needed), not as root."

log "Checking CPU virtualization support..."
if ! grep -Eq '(vmx|svm)' /proc/cpuinfo; then
  die "No VT-x/AMD-V found in /proc/cpuinfo. Enable virtualization in the BIOS/UEFI first."
fi

log "Installing packages (will prompt for sudo)..."
sudo apt-get update
sudo apt-get install -y \
  qemu-system-x86 qemu-utils \
  libvirt-daemon-system libvirt-clients \
  virtinst virt-manager virt-viewer \
  ovmf swtpm swtpm-tools \
  xorriso wget curl \
  gettext-base uuid-runtime

log "Enabling the libvirt daemon..."
sudo systemctl enable --now libvirtd

log "Ensuring the default NAT network exists and is running..."
if ! sudo virsh net-info default >/dev/null 2>&1; then
  sudo virsh net-define /usr/share/libvirt/networks/default.xml
fi
sudo virsh net-autostart default >/dev/null 2>&1 || true
sudo virsh net-start default >/dev/null 2>&1 || true

log "Adding ${USER} to the kvm and libvirt groups..."
sudo usermod -aG kvm,libvirt "${USER}"

if [[ ! -e /dev/kvm ]]; then
  warn "/dev/kvm not present yet — it should appear after a reboot or re-login."
fi

cat <<MSG

$(log "Host setup complete.")
IMPORTANT: log out and back in (or run 'newgrp libvirt') so the group
membership takes effect, otherwise libvirt commands will need sudo.

Next: scripts/01-get-media.sh
MSG
