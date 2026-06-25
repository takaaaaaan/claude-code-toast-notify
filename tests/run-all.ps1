$ErrorActionPreference = 'Stop'
$fail = 0
Get-ChildItem "$PSScriptRoot\*.tests.ps1" | ForEach-Object {
    Write-Host "== $($_.Name) =="
    try { & powershell -NoProfile -ExecutionPolicy Bypass -File $_.FullName; if ($LASTEXITCODE) { $fail++ } }
    catch { Write-Host $_; $fail++ }
}
if ($fail) { Write-Host "FAILED: $fail suite(s)"; exit 1 } else { Write-Host "ALL SUITES PASSED" }
