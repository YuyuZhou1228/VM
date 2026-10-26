#!/usr/bin/env bash
# Build the VM: create the disk, render the answer ISO and the domain XML, then
# define and start the guest so Windows Setup runs unattended.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$(readlink -f "$0")")/lib.sh"
load_env

require_cmd qemu-img
require_cmd virsh
require_cmd xorriso
require_cmd envsubst
require_cmd uuidgen

mkdir -p "${VM_DIR}"

# Persist a stable MAC + system UUID so rebuilds and ports keep one identity.
if [[ -z "${MAC_ADDR:-}" ]]; then
  MAC_ADDR="$(printf '00:1b:fc:%02x:%02x:%02x' $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)))"
  persist_env MAC_ADDR "${MAC_ADDR}"
  log "Generated stable MAC ${MAC_ADDR} (saved to config/vm.env)"
fi
if [[ -z "${VM_UUID:-}" ]]; then
  VM_UUID="$(uuidgen)"
  persist_env VM_UUID "${VM_UUID}"
  log "Generated stable system UUID ${VM_UUID} (saved to config/vm.env)"
fi

# --- disk -------------------------------------------------------------------
DISK_PATH="${VM_DIR}/${VM_NAME}.qcow2"
if [[ -f "${DISK_PATH}" ]]; then
  warn "Disk already exists (${DISK_PATH}); leaving it untouched."
else
  log "Creating ${DISK_GB}G qcow2 disk..."
  qemu-img create -f qcow2 "${DISK_PATH}" "${DISK_GB}G" >/dev/null
fi

# --- answer-file ISO --------------------------------------------------------
log "Rendering autounattend.xml..."
ANSWER_DIR="${VM_DIR}/answer"
ANSWER_ISO="${VM_DIR}/answer.iso"
mkdir -p "${ANSWER_DIR}"
export WIN_EDITION WIN_USERNAME WIN_PASSWORD WIN_HOSTNAME WIN_LOCALE WIN_TIMEZONE
envsubst '${WIN_EDITION} ${WIN_USERNAME} ${WIN_PASSWORD} ${WIN_HOSTNAME} ${WIN_LOCALE} ${WIN_TIMEZONE}' \
  < "${REPO_ROOT}/unattended/autounattend.xml.template" > "${ANSWER_DIR}/autounattend.xml"
cp "${REPO_ROOT}/unattended/guest/FirstLogon.ps1" "${ANSWER_DIR}/FirstLogon.ps1"
log "Building answer ISO (${ANSWER_ISO})..."
xorriso -as mkisofs -quiet -V UNATTEND -J -r -o "${ANSWER_ISO}" "${ANSWER_DIR}"

# --- CPU definition ---------------------------------------------------------
TOPO="    <topology sockets='${CPU_SOCKETS}' cores='${CPU_CORES}' threads='${CPU_THREADS}'/>"
if [[ "${CPU_MODE}" == "host-passthrough" ]]; then
  CPU_DEF="<cpu mode='host-passthrough' check='none' migratable='on'>
${TOPO}
  </cpu>"
elif [[ "${CPU_MODE}" == "custom" ]]; then
  CPU_DEF="<cpu mode='custom' match='exact' check='none'>
    <model fallback='allow'>${CPU_MODEL}</model>
${TOPO}
  </cpu>"
else
  die "Unknown CPU_MODE='${CPU_MODE}' (expected 'host-passthrough' or 'custom')."
fi

# --- render domain XML ------------------------------------------------------
MEM_MIB=$(( RAM_GB * 1024 ))
VCPUS=$(( CPU_SOCKETS * CPU_CORES * CPU_THREADS ))
DOMAIN_XML="${VM_DIR}/${VM_NAME}.xml"
export VM_NAME VM_UUID MEM_MIB VCPUS MACHINE_TYPE CPU_DEF DISK_PATH INSTALL_ISO VIRTIO_ISO ANSWER_ISO MAC_ADDR
envsubst '${VM_NAME} ${VM_UUID} ${MEM_MIB} ${VCPUS} ${MACHINE_TYPE} ${CPU_DEF} ${DISK_PATH} ${INSTALL_ISO} ${VIRTIO_ISO} ${ANSWER_ISO} ${MAC_ADDR}' \
  < "${REPO_ROOT}/config/vm.xml.template" > "${DOMAIN_XML}"
log "Wrote domain XML: ${DOMAIN_XML}"

# --- sanity checks ----------------------------------------------------------
[[ -f "${INSTALL_ISO}" ]] || die "Install ISO missing: ${INSTALL_ISO} (run scripts/01-get-media.sh)."
[[ -f "${VIRTIO_ISO}"  ]] || warn "virtio-win ISO missing: ${VIRTIO_ISO} (non-fatal)."

# --- define & start ---------------------------------------------------------
if virsh dominfo "${VM_NAME}" >/dev/null 2>&1; then
  warn "Domain ${VM_NAME} already defined; recreating it."
  virsh destroy "${VM_NAME}" >/dev/null 2>&1 || true
  virsh undefine --nvram "${VM_NAME}" >/dev/null 2>&1 || true
fi
log "Defining domain..."
virsh define "${DOMAIN_XML}"
log "Starting VM..."
virsh start "${VM_NAME}"

if command -v virt-viewer >/dev/null 2>&1; then
  ( virt-viewer --domain-name "${VM_NAME}" >/dev/null 2>&1 & ) || true
fi

cat <<MSG

$(log "VM started — Windows Setup should be running.")
  * If you briefly see "Press any key to boot from CD or DVD...", press a key.
  * Setup then runs unattended (it takes a while and reboots a few times).
  * At the Windows desktop, shut the guest down and run:
        scripts/03-detach-install-media.sh
    to remove the ISOs so it boots straight from its disk.
MSG
