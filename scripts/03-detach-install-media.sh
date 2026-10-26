#!/usr/bin/env bash
# After Windows is installed, eject the install/answer/virtio ISOs so the guest
# boots straight from its disk. Run with the VM shut down.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$(readlink -f "$0")")/lib.sh"
load_env
require_cmd virsh

virsh dominfo "${VM_NAME}" >/dev/null 2>&1 || die "No domain '${VM_NAME}' defined."

log "Ejecting install/answer/virtio media from ${VM_NAME}..."
for dev in sdb sdc sdd; do
  if virsh change-media "${VM_NAME}" "${dev}" --eject --config >/dev/null 2>&1; then
    log "  ejected ${dev}"
  else
    warn "  nothing to eject on ${dev}"
  fi
done
log "Done. 'virsh start ${VM_NAME}' will now boot Windows from disk."
