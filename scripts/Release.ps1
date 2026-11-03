# Tags the current TOC version and pushes the tag. The GitHub Action then
# packages the addon and uploads it to CurseForge.
[CmdletBinding()]
param([switch]$Yes)
$ErrorActionPreference = 'Stop'

$repo = Split-Path $PSScriptRoot -Parent
$toc = [IO.File]::ReadAllText((Join-Path $repo 'CupCheck.toc'))
if ($toc -notmatch '(?m)^## Version:\s*(\S+)') { throw 'no Version line in TOC' }
$version = $Matches[1]
$tag = "v$version"

$changelog = [IO.File]::ReadAllText((Join-Path $repo 'CHANGELOG.md'))
if ($changelog -notmatch "(?m)^## $([regex]::Escape($version))\s*$") { throw "CHANGELOG.md has no '## $version' entry" }

if (git -C $repo status --porcelain) { throw 'working tree has uncommitted changes' }
git -C $repo fetch -q --tags
if (git -C $repo tag -l $tag) { throw "tag $tag already exists" }
if (git -C $repo rev-list 'HEAD..origin/main' --count) {
  if ([int](git -C $repo rev-list 'HEAD..origin/main' --count) -gt 0) { throw 'origin/main is ahead, pull first' }
}
if ([int](git -C $repo rev-list 'origin/main..HEAD' --count) -gt 0) { throw 'unpushed commits, push first' }

if (-not $Yes) {
  $answer = Read-Host "Tag and publish $tag to CurseForge? (y/N)"
  if ($answer -ne 'y') { Write-Host 'Cancelled.'; exit 0 }
}
git -C $repo tag $tag
git -C $repo push -q origin $tag
Write-Host "Pushed $tag. Watch https://github.com/810anon/cupcheck/actions"
