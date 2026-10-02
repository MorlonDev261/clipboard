$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
$jbr = Join-Path $env:USERPROFILE '.jdks\jbr-21.0.11'
$collector = Join-Path $PSScriptRoot 'collect_release_artifacts.ps1'

if (Test-Path $jbr) {
  $env:JAVA_HOME = $jbr
  $env:Path = "$env:JAVA_HOME\bin;$env:Path"
}

Push-Location $repo
try {
  flutter build apk --release
  powershell -NoProfile -ExecutionPolicy Bypass -File $collector
} finally {
  Pop-Location
}
