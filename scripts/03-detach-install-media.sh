#!/usr/bin/env bash
# After Windows is installed, REMOVE the install/answer/virtio CD drives so the
# guest boots straight from its disk. Run with the VM shut down.
#
# We detach the whole cdrom devices rather than just ejecting the discs: an
# ejected-but-present drive still enumerates as "QEMU DVD-ROM" in Device
# Manager (a VM tell), and a real desktop rarely has three optical drives.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$(readlink -f "$0")")/lib.sh"
load_env
require_cmd virsh

virsh dominfo "${VM_NAME}" >/dev/null 2>&1 || die "No domain '${VM_NAME}' defined."

if virsh domstate "${VM_NAME}" 2>/dev/null | grep -q running; then
  die "Shut the guest down first (this edits the persistent config with --config)."
fi

log "Removing install/answer/virtio CD drives from ${VM_NAME}..."
for dev in sdb sdc sdd; do
  if virsh detach-disk "${VM_NAME}" "${dev}" --config >/dev/null 2>&1; then
    log "  removed ${dev}"
  else
    warn "  no device on ${dev} (already removed?)"
  fi
done
log "Done. 'virsh start ${VM_NAME}' will now boot Windows from disk."
