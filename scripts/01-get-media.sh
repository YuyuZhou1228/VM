#!/usr/bin/env bash
# Fetch the install media: the Windows ISO and the virtio-win driver ISO.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$(readlink -f "$0")")/lib.sh"
load_env

mkdir -p "$(dirname "${INSTALL_ISO}")" "$(dirname "${VIRTIO_ISO}")"

# --- virtio-win (always useful: QEMU guest agent + optional drivers) --------
if [[ -f "${VIRTIO_ISO}" ]]; then
  log "virtio-win already present: ${VIRTIO_ISO}"
else
  log "Downloading virtio-win (stable)..."
  wget -O "${VIRTIO_ISO}" \
    "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"
fi

# --- Windows ISO ------------------------------------------------------------
case "${ISO_SOURCE}" in
  quickget)
    if [[ -f "${INSTALL_ISO}" ]]; then
      log "Windows ISO already present: ${INSTALL_ISO}"
    else
      if ! command -v quickget >/dev/null 2>&1; then
        warn "quickget not found; trying to install the quickemu package..."
        if ! sudo apt-get install -y quickemu; then
          warn "apt install failed; fetching the standalone quickget script..."
          sudo wget -O /usr/local/bin/quickget \
            "https://raw.githubusercontent.com/quickemu-project/quickemu/master/quickget"
          sudo chmod +x /usr/local/bin/quickget
        fi
      fi
      tmpd="$(mktemp -d)"
      log "Downloading the official Windows 11 ISO via quickget (large; be patient)..."
      ( cd "${tmpd}" && quickget windows 11 )
      got="$(find "${tmpd}" -iname '*.iso' | head -n1 || true)"
      [[ -n "${got}" ]] || die "quickget did not produce an ISO under ${tmpd}."
      mv "${got}" "${INSTALL_ISO}"
      rm -rf "${tmpd}"
      log "Saved Windows ISO to ${INSTALL_ISO}"
    fi
    ;;
  manual)
    [[ -f "${INSTALL_ISO}" ]] || die "ISO_SOURCE=manual but no ISO at ${INSTALL_ISO}. Put your ISO there (e.g. a Win11 Enterprise Evaluation ISO)."
    log "Using provided ISO: ${INSTALL_ISO}"
    ;;
  *)
    die "Unknown ISO_SOURCE='${ISO_SOURCE}' (expected 'quickget' or 'manual')."
    ;;
esac

log "Media ready. Next: scripts/02-build-vm.sh"
