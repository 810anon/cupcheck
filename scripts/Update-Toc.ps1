# Reads the installed WoW build numbers from .build.info and adds any missing
# interface numbers to CupCheck.toc. Bumps the patch version, commits and pushes.
# Never removes numbers, never tags a release (see Release.ps1).
[CmdletBinding()]
param(
  [string]$WowRoot = 'C:\Program Files\World of Warcraft',
  [string]$BuildInfo,
  [switch]$DryRun,
  [switch]$NoPush
)
$ErrorActionPreference = 'Stop'

$repo = Split-Path $PSScriptRoot -Parent
$toc = Join-Path $repo 'CupCheck.toc'
$log = Join-Path $PSScriptRoot 'update-toc.log'
# wow = Midnight retail, wowf = Forever, wowt = PTR, wow_beta = retail beta
$products = 'wow', 'wowf', 'wowt', 'wow_beta'

function Log($msg) {
  $line = '{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $msg
  Add-Content -Path $log -Value $line
  Write-Host $line
}

function Notify($title, $body) {
  try {
    [void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
    $xml = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
    $nodes = $xml.GetElementsByTagName('text')
    [void]$nodes.Item(0).AppendChild($xml.CreateTextNode($title))
    [void]$nodes.Item(1).AppendChild($xml.CreateTextNode($body))
    $appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show([Windows.UI.Notifications.ToastNotification]::new($xml))
  } catch { }
}

if (-not $BuildInfo) { $BuildInfo = Join-Path $WowRoot '.build.info' }
if (-not (Test-Path $BuildInfo)) { Log "build.info not found: $BuildInfo"; exit 1 }

$lines = Get-Content $BuildInfo
$cols = $lines[0].Split('|') | ForEach-Object { ($_ -split '!')[0] }
$iProduct = $cols.IndexOf('Product')
$iVersion = $cols.IndexOf('Version')

$found = @{}
foreach ($l in ($lines | Select-Object -Skip 1)) {
  $f = $l.Split('|')
  if ($products -notcontains $f[$iProduct]) { continue }
  $v = $f[$iVersion].Split('.')
  if ($v.Count -lt 3) { continue }
  $found[$f[$iProduct]] = [int]$v[0] * 10000 + [int]$v[1] * 100 + [int]$v[2]
}
if ($found.Count -eq 0) { Log 'no tracked products in build.info'; exit 0 }
$summary = ($found.GetEnumerator() | Sort-Object Name | ForEach-Object { '{0}={1}' -f $_.Name, $_.Value }) -join ' '

$text = [IO.File]::ReadAllText($toc)
if ($text -notmatch '(?m)^## Interface:\s*([^\r\n]+)') { Log 'no Interface line in TOC'; exit 1 }
$current = $Matches[1].Split(',') | ForEach-Object { [int]$_.Trim() }
$add = @($found.Values | Sort-Object -Unique | Where-Object { $current -notcontains $_ })
if ($add.Count -eq 0) { Log "up to date ($summary)"; exit 0 }

$newList = (@($current) + $add | Sort-Object -Unique) -join ', '
if ($text -notmatch '(?m)^## Version:\s*(\d+)\.(\d+)\.(\d+)') { Log 'no Version line in TOC'; exit 1 }
$oldVer = '{0}.{1}.{2}' -f $Matches[1], $Matches[2], $Matches[3]
$newVer = '{0}.{1}.{2}' -f $Matches[1], $Matches[2], ([int]$Matches[3] + 1)
$msg = "Interface +$($add -join ', ') ($summary), version $oldVer -> $newVer"

if ($DryRun) { Log "DRY RUN: $msg"; exit 0 }

$changelog = Join-Path $repo 'CHANGELOG.md'
if (git -C $repo status --porcelain -- CupCheck.toc CHANGELOG.md) { Log 'TOC or CHANGELOG has uncommitted changes, aborting'; exit 1 }
if ((git -C $repo rev-parse --abbrev-ref HEAD) -ne 'main') { Log 'not on main, aborting'; exit 1 }

$text = $text -replace '(?m)^## Interface:[^\r\n]*', "## Interface: $newList"
$text = $text -replace '(?m)^## Version:[^\r\n]*', "## Version: $newVer"
[IO.File]::WriteAllText($toc, $text, (New-Object Text.UTF8Encoding($false)))

$cl = [IO.File]::ReadAllText($changelog)
$entry = "## $newVer`n- Added support for WoW interface version $($add -join ', ').`n`n"
$cl = $cl -replace '(?m)^(# Changelog\r?\n\r?\n)', "`$1$entry"
[IO.File]::WriteAllText($changelog, $cl, (New-Object Text.UTF8Encoding($false)))

git -C $repo add CupCheck.toc CHANGELOG.md
git -C $repo commit -q -m "Bump interface to $newList" -m 'Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>'
if (-not $NoPush) { git -C $repo push -q }
Log "BUMPED: $msg"

# Auto-release is opt-in: create scripts\auto-release.enabled to turn it on, delete it to turn it off.
$released = $false
$autoRelease = Test-Path (Join-Path $PSScriptRoot 'auto-release.enabled')
# Inert until a first release tag exists, so the first release is always done by hand.
git -C $repo fetch -q --tags
$hasRelease = [bool](git -C $repo tag -l 'v*')
if ($autoRelease -and -not $hasRelease) { Log 'auto-release waiting: no release tag yet (run scripts\Release.ps1 once)' }
if (-not $NoPush -and $autoRelease -and $hasRelease) {
  try {
    & (Join-Path $PSScriptRoot 'Release.ps1') -Yes
    $released = $true
    Log "RELEASED v$newVer"
  } catch {
    Log "release failed: $_"
  }
}
if ($released) {
  Notify 'Cup Check released' "Interface $newList published as v$newVer."
} else {
  Notify 'Cup Check TOC bumped' "Interface $newList, version $newVer. Run scripts\Release.ps1 to publish."
}
