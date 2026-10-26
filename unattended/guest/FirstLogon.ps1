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

# Install the QEMU guest agent from the virtio-win CD if it's attached.
foreach ($d in 'D','E','F','G','H','I','J') {
  $msi = "${d}:\guest-agent\qemu-ga-x86_64.msi"
  if (Test-Path $msi) {
    Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /qn /norestart" -Wait
    break
  }
}

# Add your own provisioning below (app installs, registry tweaks, etc.).
