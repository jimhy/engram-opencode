# engram x opencode installer (Windows).
# Copies the plugin into opencode's auto-loaded plugin dir and the bundled assets (engine
# binaries + reviewer prompt + skill) next to it, so opencode picks them up with no config edit.
#   plugin -> <config>/plugin/engram.ts        (auto-loaded by opencode)
#   assets -> <config>/engram-data/{bin,scripts,skills}
# Default config dir: %USERPROFILE%\.config\opencode (override with -ConfigDir).
param([string]$ConfigDir = (Join-Path $env:USERPROFILE '.config\opencode'))
$ErrorActionPreference = 'Stop'

$src       = $PSScriptRoot
$pluginSrc = Join-Path $src 'opencode-plugin'
$pluginDir = Join-Path $ConfigDir 'plugin'
$dataDir   = Join-Path $ConfigDir 'engram-data'

New-Item -ItemType Directory -Force -Path $pluginDir | Out-Null
New-Item -ItemType Directory -Force -Path $dataDir   | Out-Null

Copy-Item (Join-Path $pluginSrc 'plugin\engram.ts') (Join-Path $pluginDir 'engram.ts') -Force
foreach ($d in 'bin', 'scripts', 'skills') {
    $target = Join-Path $dataDir $d
    if (Test-Path $target) { Remove-Item $target -Recurse -Force }
    Copy-Item (Join-Path $pluginSrc $d) $target -Recurse -Force
}

# The reviewer/query agents and /engram-* commands are self-provisioned at runtime via the plugin's
# `config` hook — no agent/command files to install. Remove any leftover file from older versions so
# it does not shadow the injected one.
$staleAgent = Join-Path $ConfigDir 'agent\engram-reviewer.md'
if (Test-Path $staleAgent) { Remove-Item $staleAgent -Force }

Write-Host 'engram x opencode installed:'
Write-Host "  plugin -> $(Join-Path $pluginDir 'engram.ts')"
Write-Host "  assets -> $dataDir"
Write-Host 'Open opencode; the memory hot-index is injected at session start, and an independent'
Write-Host 'reviewer consolidates memory when a session goes idle (increment >= ENGRAM_REVIEW_MIN_LINES).'
