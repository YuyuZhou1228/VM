# Portability — moving the VM between your two machines

The whole project is designed so the VM is **two artifacts** you can carry
between machines:

1. the **disk image** (`<VM_DIR>/<VM_NAME>.qcow2`), and
2. the **machine definition** (the libvirt domain XML).

`scripts/04-package-port.sh` bundles both into a single `.tar`;
`scripts/05-import-on-target.sh` unpacks it on the other machine, fixes the
host-specific paths, and defines the domain. Keep the repo itself alongside the
bundle so `config/vm.env` (with your stable MAC and UUID) travels too.

## What ports as-is

- The disk contents and everything installed in Windows.
- The SMBIOS identity, MAC, and system UUID (kept in `config/vm.env`), so the
  guest sees the *same* "hardware" on both machines and won't treat it as new.
- The device layout in the XML.

## The one thing to get right: the CPU

This is the only setting that meaningfully affects whether the VM boots cleanly
on the other machine.

- **`CPU_MODE=host-passthrough`** (default) presents each host's own CPU. Fine if
  both machines have **similar CPUs from the same vendor**. If they differ a lot
  (or one is Intel and the other AMD), Windows may complain or want to
  re-activate — though since we install **unactivated**, reactivation isn't a
  concern here.
- **`CPU_MODE=custom`** with a named `CPU_MODEL` presents the *same* virtual CPU
  on both machines, which is the robust choice for a two-machine project. Pick a
  model both CPUs can support — effectively a common baseline.

### Computing a safe baseline model

On **each** machine, run:

```bash
virsh domcapabilities | grep -A2 '<mode name=.host-model'
```

to see what libvirt would pick, and:

```bash
# Compare/merge the two hosts' capabilities to find a common baseline:
virsh hypervisor-cpu-baseline /path/to/hostA-domcaps.xml /path/to/hostB-domcaps.xml
```

Use the resulting model name as `CPU_MODEL` and set `CPU_MODE=custom`. If both
machines are the same vendor and generation, a conservative named model (e.g. an
Intel `Haswell-noTSX-IBRS` or an AMD `EPYC`-class model) is usually enough.

## Machine type

`MACHINE_TYPE` should be a Q35 version that **both** machines' QEMU installs
know. If one machine has a newer QEMU, a machine type it emits (e.g.
`pc-q35-9.0`) may be unknown to an older QEMU on the other. Options:

- Keep `MACHINE_TYPE=q35` (newest available) if both machines run the same
  Ubuntu release / QEMU version — the simplest path, and likely your case.
- Otherwise pin an explicit shared version, e.g. `MACHINE_TYPE=pc-q35-8.2`, that
  `qemu-system-x86_64 -machine help` lists on **both**.

## UEFI nvram

The import script drops the nvram path so libvirt regenerates UEFI variables
locally. If Windows doesn't appear in the boot menu after import, enter the
guest's UEFI setup once and select the Windows Boot Manager, or re-add a boot
entry — a one-time fix, not a per-boot issue.

## Networking

The VM uses libvirt's **default NAT network**, which exists identically on every
libvirt install, so networking ports with no changes. (If you switch to a bridge
for LAN presence, the bridge name is host-specific and you'll adjust it per
machine.)

## Quick port checklist

1. `virsh shutdown <VM_NAME>` on the source machine.
2. `scripts/04-package-port.sh` → produces `<VM_NAME>-port.tar`.
3. Copy the `.tar` **and** this repo to the target machine.
4. Run `scripts/00-host-setup.sh` once on the target (if not already done).
5. Decide CPU strategy (above); edit `config/vm.env` if using `custom`.
6. `scripts/05-import-on-target.sh <VM_NAME>-port.tar`.
7. `virsh start <VM_NAME>`.
