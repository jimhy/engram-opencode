# Extract engram-opencode into a self-contained bundle to hand to the opencode desktop project
# (so it can ship engram inside the app instead of via npm). Output layout:
#   <out>/plugin/engram.ts
#   <out>/engram-data/{bin,scripts,skills}
#   <out>/DESKTOP_INTEGRATION.md
# Usage: .\export-desktop-bundle.ps1 [-OutDir <path>]   (default: .\engram-desktop-bundle)
param([string]$OutDir = (Join-Path $PSScriptRoot 'engram-desktop-bundle'))
$ErrorActionPreference = 'Stop'

$src = $PSScriptRoot
$pkg = Join-Path $src 'opencode-plugin'

if (Test-Path $OutDir) { Remove-Item $OutDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path (Join-Path $OutDir 'plugin') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $OutDir 'engram-data\bin') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $OutDir 'engram-data\scripts') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $OutDir 'engram-data\skills\engram') | Out-Null

Copy-Item (Join-Path $pkg 'plugin\engram.ts')           (Join-Path $OutDir 'plugin\engram.ts') -Force
Copy-Item (Join-Path $pkg 'bin\engram-*')               (Join-Path $OutDir 'engram-data\bin') -Force
Copy-Item (Join-Path $pkg 'scripts\reviewer-prompt.md') (Join-Path $OutDir 'engram-data\scripts\reviewer-prompt.md') -Force
Copy-Item (Join-Path $pkg 'skills\engram\SKILL.md')     (Join-Path $OutDir 'engram-data\skills\engram\SKILL.md') -Force
Copy-Item (Join-Path $src 'DESKTOP_INTEGRATION.md')     (Join-Path $OutDir 'DESKTOP_INTEGRATION.md') -Force

Write-Host "engram-opencode desktop bundle ->"
Write-Host "  $OutDir"
Get-ChildItem -Recurse -File $OutDir | ForEach-Object { '  ' + $_.FullName.Substring($OutDir.Length + 1) }
Write-Host ''
Write-Host "Copy the whole '$OutDir' folder to the opencode desktop project; follow DESKTOP_INTEGRATION.md."
