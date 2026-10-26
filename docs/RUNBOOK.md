# Runbook — build the VM on your Ubuntu machine

Follow these in order on the **Ubuntu** side of your machine (not Windows — the
whole thing needs `/dev/kvm`, which only exists on Linux).

## 0. Prerequisites

- Ubuntu 22.04 / 24.04 (or similar), booted natively.
- Virtualization (VT-x/AMD-V) enabled in BIOS/UEFI.
- ~100 GB free disk for the ISO + the VM disk.
- Claude Code installed locally (optional, if you want to keep iterating with it):
  `curl -fsSL https://claude.ai/install.sh | bash`

## 1. Get the repo

```bash
git clone https://github.com/YuyuZhou1228/VM.git
cd VM
```

## 2. Configure

```bash
cp config/vm.env.example config/vm.env
# Edit config/vm.env — at minimum review:
#   RAM_GB, DISK_GB, CPU_* (keep total vCPUs <= your core count)
#   WIN_PASSWORD (change it)
#   ISO_SOURCE (quickget = auto-download official ISO; manual = your own ISO)
nano config/vm.env
```

## 3. One-time host setup

```bash
./scripts/00-host-setup.sh
# then LOG OUT and back in (for the kvm/libvirt group membership), or:
newgrp libvirt
```

## 4. Get the install media

```bash
./scripts/01-get-media.sh
# Downloads the Windows ISO (if ISO_SOURCE=quickget) and the virtio-win ISO.
```

## 5. Build and install

```bash
./scripts/02-build-vm.sh
```

- A window opens (virt-viewer). If you briefly see **"Press any key to boot
  from CD or DVD…"**, press a key — this is the one unavoidable manual moment.
- Windows Setup then runs unattended: it partitions the disk, installs, reboots
  a few times, creates your local admin account, and lands on the desktop.
- If a build/edition picker or a single OOBE prompt appears, it means the ISO's
  edition name didn't match `WIN_EDITION` or your Windows build changed an OOBE
  step — just click through that once; everything else is automated.

## 6. Finalize

```bash
# Shut the guest down from inside Windows (or: virsh shutdown <VM_NAME>), then:
./scripts/03-detach-install-media.sh
virsh start <VM_NAME>     # now boots straight from disk
```

You now have a running, bare-metal-styled Windows VM. The "Activate Windows"
watermark is expected (it's unactivated) — see the README for the eval-ISO
option if you want a clean desktop.

## 7. (Later) Move it to the other machine

See `docs/PORTABILITY.md`. In short: `04-package-port.sh` here →
copy the `.tar` + repo over → `05-import-on-target.sh` there.

## Tuning fidelity

Edit the `<sysinfo>` block and device models in `config/vm.xml.template`, then
re-run `./scripts/02-build-vm.sh` (it redefines the domain; it won't recreate an
existing disk). See `docs/FIDELITY.md` for what each knob does.

## Troubleshooting

- **`virsh` wants a password / permission denied** → you didn't re-login after
  `00-host-setup.sh`; run `newgrp libvirt` or log out and back in.
- **No `/dev/kvm`** → virtualization is off in BIOS/UEFI, or you're booted into
  Windows by mistake.
- **VM won't boot after install** → you may not have ejected the install ISO
  (step 6), so it keeps booting the installer; or set the boot entry once in the
  guest UEFI menu.
- **Secure Boot blocks install** → set `<loader secure='no'/>` in the template
  (and remove `smm`) if your OVMF build is fussy, then rebuild.
