#!/usr/bin/env bash
# On the SOURCE machine: bundle the VM (disk + runtime XML) so it can be moved
# to another machine. Shut the VM down first for a consistent disk image.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$(readlink -f "$0")")/lib.sh"
load_env
require_cmd virsh
require_cmd tar

virsh dominfo "${VM_NAME}" >/dev/null 2>&1 || die "No domain '${VM_NAME}' defined here."

state="$(virsh domstate "${VM_NAME}" 2>/dev/null || echo unknown)"
if [[ "${state}" != "shut off" ]]; then
  warn "VM state is '${state}'. Shut it down first for a clean copy:"
  warn "    virsh shutdown ${VM_NAME}"
  die  "Aborting."
fi

DISK_PATH="${VM_DIR}/${VM_NAME}.qcow2"
[[ -f "${DISK_PATH}" ]] || die "Disk not found: ${DISK_PATH}"

EXPORT_XML="${VM_DIR}/${VM_NAME}.runtime.xml"
log "Dumping runtime domain XML..."
virsh dumpxml "${VM_NAME}" > "${EXPORT_XML}"

OUT="${VM_DIR%/}/../${VM_NAME}-port.tar"
log "Packaging disk + XML into ${OUT} (this can be large)..."
tar -C "${VM_DIR}" -cf "${OUT}" "${VM_NAME}.qcow2" "${VM_NAME}.runtime.xml"

cat <<MSG

$(log "Package ready: ${OUT}")
Copy it to the target machine together with this repo (so config/vm.env comes
along), then on the target run:
    scripts/05-import-on-target.sh "/path/to/${VM_NAME}-port.tar"

Before first boot on the target, read docs/PORTABILITY.md — the one thing worth
checking is the CPU model (CPU_MODE in config/vm.env).
MSG
