# Bare-metal-fidelity Windows VM (QEMU/KVM)

A portable, scripted **Windows 11 virtual machine on QEMU/KVM** tuned to present
itself like a physical OEM machine rather than a generic VM — and built so it
moves cleanly between two different Linux hosts.

This repo is the *configuration and tooling* layer on top of QEMU/KVM/libvirt.
It does **not** reinvent the emulator — QEMU already emulates real chipsets
better than anything hand-rolled. The project's value is the fidelity profile
(SMBIOS, CPU, device models, firmware) and the portable, reproducible build
scripts around it.

## What you get

- A libvirt domain template with fidelity-first defaults (realistic SMBIOS/DMI,
  SATA disk, Intel e1000e NIC, TPM 2.0, Secure Boot, no paravirtual tells, host
  CPU, Hyper-V enlightenments for a smooth Windows).
- Fully **unattended** Windows install (no clicking through Setup).
- One-command **host setup**, **media download**, and **build**.
- **Port** scripts to carry the VM between machines as a single bundle.
- Docs explaining every fidelity knob and the portability model.

## Requirements (honest list)

- An **Ubuntu/Linux host** booted natively (needs `/dev/kvm` — a cloud box or
  the Windows side of a dual-boot won't work).
- Virtualization enabled in BIOS/UEFI.
- A **Windows 11 ISO**. `ISO_SOURCE=quickget` auto-downloads the official
  Microsoft retail ISO and installs it **unactivated** (works indefinitely, has
  a desktop watermark). For a clean desktop, download a **Windows 11 Enterprise
  Evaluation** ISO by hand and set `ISO_SOURCE=manual` (clean for 90 days).
- No product key needed; this installs unactivated by design. See
  `docs/FIDELITY.md` §activation notes in the runbook.

## Quickstart

```bash
git clone https://github.com/YuyuZhou1228/VM.git && cd VM
cp config/vm.env.example config/vm.env     # edit to taste
./scripts/00-host-setup.sh                 # once per machine; then re-login
./scripts/01-get-media.sh                  # fetch Windows + virtio-win ISOs
./scripts/02-build-vm.sh                   # create, define, and run the VM
# ...Windows installs unattended; at the desktop, shut down, then:
./scripts/03-detach-install-media.sh
```

Full step-by-step: [`docs/RUNBOOK.md`](docs/RUNBOOK.md).

## Repository layout

```
config/
  vm.env.example        # all configuration (copy to vm.env)
  vm.xml.template       # libvirt domain template — the fidelity profile
scripts/
  lib.sh                # shared helpers
  00-host-setup.sh      # install qemu/kvm/libvirt/ovmf/swtpm, groups, network
  01-get-media.sh       # download Windows ISO (+ virtio-win)
  02-build-vm.sh        # render answer ISO + domain XML, define + start
  03-detach-install-media.sh   # eject ISOs after install
  04-package-port.sh    # bundle disk + XML to move to another machine
  05-import-on-target.sh# import the bundle on the other machine
unattended/
  autounattend.xml.template    # unattended Windows Setup answer file
  guest/FirstLogon.ps1         # optional first-logon tweaks (runs in guest)
docs/
  RUNBOOK.md            # do-this-then-that for the Ubuntu machine
  FIDELITY.md           # what each bare-metal knob does, and the trade-offs
  PORTABILITY.md        # moving the VM between your two machines
```

## Scope and non-goals

- **Not included: GPU passthrough.** It's the ultimate bare-metal touch but is
  hardware-specific and non-portable, so it's left for a per-machine add-on once
  the portable base works. See `docs/FIDELITY.md` §7.
- This is a personal/educational project for high-fidelity desktop
  virtualization. Use your own Windows licensing.

## Status

Scripts are authored to run on a native Ubuntu host; they could not be executed
in the environment where they were written (no `/dev/kvm` there), so run them
step by step the first time and read `docs/RUNBOOK.md` troubleshooting if a step
needs adjusting for your exact Ubuntu/QEMU version.
