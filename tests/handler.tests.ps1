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

# when pids are present, the handler drops a focus-request file for the extension
$reqFile = Join-Path $work 'focus.json'
$env:CCTOAST_FOCUS_FILE = $reqFile
$uri2 = New-ToastLaunchUri $target 'cctoast' '111,222,33692'
powershell -ExecutionPolicy Bypass -File "$PSScriptRoot\..\cctoast-open.ps1" $uri2 | Out-Null
Remove-Item Env:\CCTOAST_FOCUS_FILE
Assert-True (Test-Path $reqFile) "handler wrote the focus-request file"
$req = Get-Content $reqFile -Raw | ConvertFrom-Json
Assert-Equal $req.pids '111,222,33692' "request file carries the pid chain"
Assert-True ($req.ts -gt 0) "request file carries a timestamp"

Remove-Item $work -Recurse -Force
Write-Host "handler.tests PASSED"
