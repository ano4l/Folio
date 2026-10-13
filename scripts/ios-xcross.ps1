#Requires -Version 5.1
[CmdletBinding()]
param(
  [ValidateSet('doctor', 'sdk', 'build', 'run', 'tunnel')]
  [string]$Action = 'doctor',
  [string]$XcodeArchive,
  [string]$ApiUrl,
  [switch]$Wifi
)

$ErrorActionPreference = 'Stop'
$folioMobile = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\mobile'))
# Pick up toolchain installers' PATH changes without restarting Codex.
$registeredPaths = @(
  [Environment]::GetEnvironmentVariable('Path', 'Machine'),
  [Environment]::GetEnvironmentVariable('Path', 'User'),
  $env:Path
) -join ';'
$env:Path = ($registeredPaths -split ';' | Where-Object { $_ } | Select-Object -Unique) -join ';'
$xcrossCommand = Get-Command xcross -ErrorAction SilentlyContinue
$xcrossExecutable = if ($xcrossCommand) { $xcrossCommand.Source } else {
  Join-Path $env:LOCALAPPDATA 'xcross\bin\xcross.exe'
}
if (-not (Test-Path -LiteralPath $xcrossExecutable)) {
  throw 'Install xcross first: https://github.com/arxdeus/xcross#installation'
}

Push-Location $folioMobile
try {
  if ($Action -eq 'sdk') {
    if (-not $XcodeArchive -or -not (Test-Path -LiteralPath $XcodeArchive -PathType Leaf)) {
      throw 'Provide -XcodeArchive with the downloaded Apple .xip file.'
    }
    & $xcrossExecutable sdk install ([IO.Path]::GetFullPath($XcodeArchive))
    if ($LASTEXITCODE -ne 0) { throw 'Darwin SDK installation failed.' }
    return
  }
  if ($Action -eq 'tunnel') {
    $arguments = @('tunnel')
    if ($Wifi) { $arguments += '--wifi' }
    & $xcrossExecutable @arguments
    if ($LASTEXITCODE -ne 0) { throw 'iPhone tunnel failed. Check the xcross error above. Use Administrator PowerShell, unlock and trust the phone, and enable Developer Mode. After its restart, rerun the tunnel to mount the developer disk image.' }
    return
  }

  # Doctor includes signing/device checks; an unsigned build needs neither.
  if ($Action -ne 'build') {
    & $xcrossExecutable flutter doctor
    if ($LASTEXITCODE -ne 0) { throw 'Resolve the doctor failures before running Folio.' }
  }
  if ($Action -eq 'doctor') { return }

  # Avoid silently shipping a working UI with missing native method channels.
  $pluginFile = Join-Path $folioMobile '.flutter-plugins-dependencies'
  $plugins = (Get-Content -LiteralPath $pluginFile -Raw | ConvertFrom-Json).plugins.ios
  foreach ($plugin in $plugins) {
    if ($plugin.dev_dependency -or -not $plugin.native_build) { continue }
    $platformDirectory = if ($plugin.shared_darwin_source) { 'darwin' } else { 'ios' }
    $manifest = Join-Path $plugin.path ($platformDirectory + '\' + $plugin.name + '\Package.swift')
    if (-not (Test-Path -LiteralPath $manifest)) {
      throw ($plugin.name + ' has native iOS code without a SwiftPM manifest. Adapt the plugin before building.')
    }
  }
  $arguments = @('flutter', $Action, '--no-pub')
  if ($ApiUrl) { $arguments += @('--dart-define', ('FOLIO_API_URL=' + $ApiUrl)) }
  if ($Action -eq 'run' -and $Wifi) { $arguments += '--wifi' }
  & $xcrossExecutable @arguments
  if ($LASTEXITCODE -ne 0) { throw ('xcross flutter ' + $Action + ' failed.') }
} finally {
  Pop-Location
}
