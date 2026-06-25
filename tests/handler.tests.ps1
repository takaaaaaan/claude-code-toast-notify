$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\assert.ps1"

$work = Join-Path $env:TEMP ('cctoast-handler-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
$log = Join-Path $work 'code-args.txt'
# fake `code` that records its args
"@echo off`r`n>>`"$log`" echo %*" | Set-Content (Join-Path $work 'code.cmd') -Encoding ascii

$target = Join-Path $work 'demo-workspace'
New-Item -ItemType Directory -Path $target | Out-Null
. "$PSScriptRoot\..\lib\cctoast-lib.ps1"
$uri = New-ToastLaunchUri $target

$env:PATH = "$work;$env:PATH"
# No real VS Code window matches the throwaway 'demo-workspace' leaf, so the
# handler takes the fallback branch and launches `code "<target>"`.
powershell -ExecutionPolicy Bypass -File "$PSScriptRoot\..\cctoast-open.ps1" $uri | Out-Null

Assert-True (Test-Path $log) "fake code was invoked as fallback (no existing window)"
$line = Get-Content $log -Raw
Assert-True ($line -match 'demo-workspace') "code called with the target path"
Assert-True ($line -notmatch '--reuse-window') "fallback open does not hijack another window with --reuse-window"
Remove-Item $work -Recurse -Force
Write-Host "handler.tests PASSED"
