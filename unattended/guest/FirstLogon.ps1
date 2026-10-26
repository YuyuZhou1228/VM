# FirstLogon.ps1 — optional post-install tweaks, run once at first logon.
# Referenced by autounattend.xml (FirstLogonCommands). Safe to edit or empty out.

$ErrorActionPreference = 'SilentlyContinue'

# High-performance power plan; don't sleep (behaves like a desktop/workstation).
powercfg /setactive SCHEME_MIN
powercfg /change standby-timeout-ac 0
powercfg /change monitor-timeout-ac 15
powercfg /hibernate off

# Developer-friendly Explorer defaults: show extensions and hidden files.
$exp = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
Set-ItemProperty -Path $exp -Name HideFileExt -Value 0
Set-ItemProperty -Path $exp -Name Hidden      -Value 1

# NOTE: we deliberately do NOT install the QEMU guest agent here. It installs a
# "QEMU Guest Agent" service plus files under Program Files and a VSS provider —
# all obvious "this is a QEMU VM" software traces — and this build defines no
# guest-agent channel for it to talk over anyway, so it would be pure exposure
# with no benefit. If you ever need host<->guest integration, add the matching
# <channel> device to the domain and re-enable an install here, understanding
# the fidelity cost.

# Add your own provisioning below (app installs, registry tweaks, etc.).
