# One-time setup: registers a scheduled task that runs Update-Toc.ps1 at logon
# and every 4 hours. Run once from an elevated PowerShell. The task itself runs
# as the current user with normal (limited) rights.
$ErrorActionPreference = 'Stop'

$script = Join-Path $PSScriptRoot 'Update-Toc.ps1'
$user = "$env:USERDOMAIN\$env:USERNAME"

$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
  -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`""
$triggers = @(
  (New-ScheduledTaskTrigger -AtLogOn -User $user),
  (New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(5) -RepetitionInterval (New-TimeSpan -Hours 4))
)
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries `
  -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName 'CupCheck TOC Bump' -Action $action -Trigger $triggers `
  -Settings $settings -Principal $principal -Force `
  -Description 'Adds new WoW interface numbers to CupCheck.toc and pushes to GitHub. Release is manual (scripts\Release.ps1).' |
  Select-Object TaskName, State
