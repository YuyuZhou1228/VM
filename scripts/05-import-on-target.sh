#!/usr/bin/env bash
# On the TARGET machine: import a package produced by 04-package-port.sh,
# rewrite host-specific paths, and define the domain.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$(readlink -f "$0")")/lib.sh"
load_env
require_cmd virsh
require_cmd tar

PORT_TAR="${1:-}"
[[ -n "${PORT_TAR}" && -f "${PORT_TAR}" ]] || die "Usage: $0 /path/to/${VM_NAME}-port.tar"

mkdir -p "${VM_DIR}"
log "Extracting into ${VM_DIR}..."
tar -C "${VM_DIR}" -xf "${PORT_TAR}"

DISK_PATH="${VM_DIR}/${VM_NAME}.qcow2"
SRC_XML="${VM_DIR}/${VM_NAME}.runtime.xml"
[[ -f "${DISK_PATH}" ]] || die "Disk missing after extract: ${DISK_PATH}"
[[ -f "${SRC_XML}"  ]] || die "XML missing after extract: ${SRC_XML}"

LOCAL_XML="${VM_DIR}/${VM_NAME}.local.xml"
log "Rewriting host-specific bits for this machine..."
# - point the disk at this machine's copy
# - drop the nvram path so libvirt regenerates UEFI vars locally
# - normalize the emulator path
sed -E \
  -e "s#<source file='[^']*${VM_NAME}\.qcow2'/>#<source file='${DISK_PATH}'/>#g" \
  -e "s#<nvram>[^<]*</nvram>#<nvram/>#g" \
  -e "s#<emulator>[^<]*</emulator>#<emulator>/usr/bin/qemu-system-x86_64</emulator>#g" \
  "${SRC_XML}" > "${LOCAL_XML}"

warn "If this machine's CPU differs from the source machine's, review CPU_MODE"
warn "in config/vm.env and docs/PORTABILITY.md before the first boot."

if virsh dominfo "${VM_NAME}" >/dev/null 2>&1; then
  warn "Domain ${VM_NAME} already defined here; recreating it."
  virsh destroy "${VM_NAME}" >/dev/null 2>&1 || true
  virsh undefine --nvram "${VM_NAME}" >/dev/null 2>&1 || true
fi
log "Defining domain from ${LOCAL_XML}..."
virsh define "${LOCAL_XML}"
log "Imported. Start it with:  virsh start ${VM_NAME}"
