$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
$jbr = Join-Path $env:USERPROFILE '.jdks\jbr-21.0.11'
$singleExeBuilder = Join-Path $PSScriptRoot 'make_windows_single_exe.ps1'
$collector = Join-Path $PSScriptRoot 'collect_release_artifacts.ps1'

if (Test-Path $jbr) {
  $env:JAVA_HOME = $jbr
  $env:Path = "$env:JAVA_HOME\bin;$env:Path"
}

Push-Location $repo
try {
  flutter build windows --release

  $releaseDir = Join-Path $repo 'build/windows/x64/runner/Release'
  $payload = Join-Path $repo 'build/windows/x64/runner/influencor-windows-release.zip'
  if (Test-Path $payload) {
    Remove-Item -LiteralPath $payload -Force
  }
  Compress-Archive -Path (Join-Path $releaseDir '*') -DestinationPath $payload -Force
  powershell -NoProfile -ExecutionPolicy Bypass -File $singleExeBuilder

  if (Get-Command iscc -ErrorAction SilentlyContinue) {
    iscc installer/influencor.iss
  } else {
    Write-Host 'Inno Setup compiler (iscc) not found; skipping Windows installer.'
  }

  flutter build apk --release --split-per-abi
  flutter build web --release --no-wasm-dry-run

  powershell -NoProfile -ExecutionPolicy Bypass -File $collector
} finally {
  Pop-Location
}
