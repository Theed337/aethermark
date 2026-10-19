@echo off
title Aethermark Launcher
set "AETHER_BAT=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s=[IO.File]::ReadAllText($env:AETHER_BAT); $i=$s.IndexOf(([string][char]10)+'#PS#'); iex $s.Substring($i)"
if errorlevel 1 pause
exit /b
#PS#
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$root = Split-Path -Parent $env:AETHER_BAT
$game = Join-Path $root 'Aethermark'
$exe = Join-Path $game 'Aethermark.exe'
$verFile = Join-Path $game 'installed_version.txt'
$url = 'https://raw.githubusercontent.com/Theed337/aethermark/main/dist/version.json'
Write-Host '=== Aethermark Launcher ===' -ForegroundColor Cyan
$installed = ''
if ((Test-Path $exe) -and (Test-Path $verFile)) { $installed = (Get-Content $verFile -Raw).Trim() }
$info = $null
try { $info = Invoke-RestMethod -Uri $url -UseBasicParsing } catch { Write-Host 'Keine Verbindung zu GitHub (Update-Pruefung uebersprungen).' -ForegroundColor Yellow }
$need = $false
if ($info) {
  if ($installed -eq '') { $need = $true }
  elseif ([version]$info.version -gt [version]$installed) { $need = $true }
  Write-Host ('Installiert: ' + $(if ($installed) { $installed } else { '-' }) + '   Neueste: ' + $info.version)
}
if ($need) {
  Write-Host ('Lade Version ' + $info.version + ' herunter (ca. 120 MB) ...')
  $tmp = Join-Path $env:TEMP 'aethermark_dl'
  if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
  New-Item -ItemType Directory -Path $tmp | Out-Null
  $zip = Join-Path $tmp 'game.zip'
  $out = [IO.File]::Create($zip)
  try {
    $i = 0
    foreach ($p in $info.parts) {
      $i++
      Write-Host ('  Teil ' + $i + ' von ' + $info.parts.Count + ' ...')
      $part = Join-Path $tmp ('p' + $i)
      Invoke-WebRequest -Uri $p -OutFile $part -UseBasicParsing
      $in = [IO.File]::OpenRead($part)
      $in.CopyTo($out)
      $in.Close()
      Remove-Item $part -Force
    }
  } finally { $out.Close() }
  Write-Host 'Entpacke ...'
  $ex = Join-Path $tmp 'x'
  Expand-Archive -Path $zip -DestinationPath $ex -Force
  if (-not (Test-Path $game)) { New-Item -ItemType Directory -Path $game | Out-Null }
  Copy-Item -Path (Join-Path $ex 'Aethermark\*') -Destination $game -Recurse -Force
  Set-Content -Path $verFile -Value $info.version
  Remove-Item $tmp -Recurse -Force
  Write-Host 'Fertig installiert.' -ForegroundColor Green
}
if (Test-Path $exe) {
  Write-Host 'Starte Spiel ...'
  Start-Process -FilePath $exe -WorkingDirectory $game
} else {
  Write-Host 'Spiel nicht installiert und Download nicht moeglich. Bitte Internet pruefen.' -ForegroundColor Red
  Read-Host 'Enter zum Beenden'
}
