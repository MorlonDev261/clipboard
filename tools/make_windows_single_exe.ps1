$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$runner = Join-Path $root "build\windows\x64\runner"
$payload = Join-Path $runner "influencor-windows-release.zip"
$source = Join-Path $root "tools\single_exe_launcher.cpp"
$work = Join-Path $env:TEMP "influencor_single_exe_build"
$baseExe = Join-Path $work "launcher.exe"
$out = Join-Path $runner "Influencor.exe"

if (!(Test-Path $payload)) {
  throw "Missing payload: $payload"
}

Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $work | Out-Null

$vcvars = "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
if (!(Test-Path $vcvars)) {
  throw "Visual Studio vcvars64.bat not found: $vcvars"
}

$compile = "`"$vcvars`" && cl /nologo /O2 /MT /EHsc /DUNICODE /D_UNICODE /Fe:`"$baseExe`" `"$source`" shell32.lib user32.lib"
cmd.exe /d /s /c $compile
if ($LASTEXITCODE -ne 0) {
  throw "Failed to compile launcher"
}
if (!(Test-Path $baseExe)) {
  throw "Launcher was not created"
}

$marker = [Text.Encoding]::ASCII.GetBytes("INFLUENCOR_PAYLOAD_V1")
$payloadBytes = [IO.File]::ReadAllBytes($payload)
$sizeBytes = [BitConverter]::GetBytes([UInt64]$payloadBytes.Length)

$outStream = [IO.File]::Create($out)
try {
  $baseBytes = [IO.File]::ReadAllBytes($baseExe)
  $outStream.Write($baseBytes, 0, $baseBytes.Length)
  $outStream.Write($payloadBytes, 0, $payloadBytes.Length)
  $outStream.Write($sizeBytes, 0, $sizeBytes.Length)
  $outStream.Write($marker, 0, $marker.Length)
} finally {
  $outStream.Dispose()
}

Get-Item $out | Select-Object FullName, Length, LastWriteTime
