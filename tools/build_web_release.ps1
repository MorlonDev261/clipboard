$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
$collector = Join-Path $PSScriptRoot 'collect_release_artifacts.ps1'

Push-Location $repo
try {
  flutter build web --release --no-wasm-dry-run
  powershell -NoProfile -ExecutionPolicy Bypass -File $collector
} finally {
  Pop-Location
}
