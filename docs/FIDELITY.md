# Fidelity notes — making the VM present like a physical machine

This file explains *why* each setting in `config/vm.xml.template` is the way it
is, and what a real machine looks like at that layer. Tune these to taste; the
defaults aim for a believable, well-behaved Windows desktop rather than an
obviously generic VM.

A VM reveals itself at a handful of layers. Below, each one is paired with the
choice this project makes.

## 1. Firmware tables (SMBIOS / DMI)

**What a real machine shows:** a real BIOS vendor, board manufacturer and model,
and non-empty serial numbers — the strings `systeminfo`, `wmic baseboard get
product`, and Device Manager read back.

**What we do:** the `<sysinfo type='smbios'>` block sets a consistent OEM
identity (vendor + a real board model + plausible serials). Defaults use an ASUS
desktop board; edit them to match a machine you actually own for the best
result. Keep the pieces internally consistent — a board model that really
belongs to the vendor you named, a BIOS version that vendor really shipped.

> Tip: on a real Linux box run `sudo dmidecode` to see exactly which fields a
> physical machine fills in, and mirror that shape.

## 2. CPU

**What a real machine shows:** a specific CPU model, and no paravirtual
hypervisor interface.

**What we do:** `CPU_MODE=host-passthrough` presents the host CPU model verbatim
(most faithful). `<kvm><hidden state='on'/></kvm>` hides the KVM paravirtual
CPUID leaf, which is the standard setting so that real GPU drivers behave once
you move to GPU passthrough.

**The honest trade-off:** we also enable Hyper-V *enlightenments* (`<hyperv>`).
These make Windows schedule, time, and idle far more efficiently under KVM — a
big stability and performance win — but they do advertise a Hyper-V interface to
the guest, which is itself a "this is virtualized" signal. This is the usual
desktop/gaming-VM compromise: keep the enlightenments for a smooth Windows, and
accept that a determined check can still see a hypervisor. If you want to
minimize that signal instead, you can drop the `<hyperv>` block and add
`<feature policy='disable' name='hypervisor'/>` to the `<cpu>` element — expect
a noticeably less smooth Windows in return. You can't fully have both.

## 3. Disks

**What a real machine shows:** an ATA/NVMe drive with a model and serial.

**What we do:** the primary disk is attached as a **SATA** device rather than
virtio. Two benefits: Windows has in-box SATA drivers (so no driver injection
during install), and a SATA disk reads like a real drive. We also set a plausible
`<serial>`. Virtio disks are faster but are an obvious paravirtual tell; SATA is
the fidelity-first choice. (NVMe emulation is another realistic option if you
want to experiment — it lets you set a model string too.)

## 4. Network

**What a real machine shows:** a real NIC (Intel/Realtek/etc.) with a MAC whose
prefix (OUI) belongs to a real vendor.

**What we do:** an emulated **e1000e** (Intel Gigabit) NIC — in-box Windows
driver, reads as real hardware — instead of virtio-net. `scripts/lib.sh`
generates a MAC under a real-vendor OUI (`00:1b:fc`, ASUSTeK) rather than the
giveaway QEMU range (`52:54:00`). The MAC is persisted so it stays stable.

## 5. TPM, Secure Boot, timers

- **TPM 2.0** via swtpm — required by Windows 11, and present on modern real
  machines.
- **Secure Boot** via the OVMF secure loader (`<loader secure='yes'/>` with
  `smm`), matching a stock Windows 11 machine.
- **Timers/clock**: `localtime` RTC (what Windows expects) and the Hyper-V clock
  for efficient timekeeping.

## 6. Virtual-only devices we remove

- **No memory balloon** (`<memballoon model='none'/>`) — the balloon is a
  paravirtual-only device and buys little here.
- No VMware/VirtualBox-style guest-tools channels; the only guest integration is
  the optional QEMU guest agent, which you can also leave out.

## 7. The display — the one honest gap

Without a real GPU, the video adapter is emulated (`vga` here), and that is the
most visible "it's a VM" tell of all. There is no software trick around it: the
bare-metal endgame is **GPU passthrough** (give the guest a real graphics card
via VFIO) plus optionally Looking Glass to view it. That is hardware-specific
and therefore **not portable**, so this project leaves it out of the base build.
Add it per-machine once the portable base works — see the Arch Wiki
"PCI passthrough via OVMF" guide.

## 8. Things fidelity can't fake, and shouldn't be ignored

A convincing machine is also a *lived-in* one: realistic uptime, installed apps,
a sensible screen resolution, a disk that isn't a pristine 80 GB with 3 files.
Those come from using the VM, not from config. Note them, but they're out of
scope for the hardware layer this repo builds.
