$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\assert.ps1"
. "$PSScriptRoot\..\lib\cctoast-lib.ps1"

$work = Join-Path $env:TEMP ('cctoast-handler-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
$log = Join-Path $work 'code-args.txt'
# fake `code` on PATH that records its args (must NEVER be called now)
"@echo off`r`n>>`"$log`" echo %*" | Set-Content (Join-Path $work 'code.cmd') -Encoding ascii
$env:PATH = "$work;$env:PATH"

$target = Join-Path $work 'demo-workspace'
New-Item -ItemType Directory -Path $target | Out-Null
$handler = "$PSScriptRoot\..\cctoast-open.ps1"

try {
    # --- Part A: no extension, no matching window -> handler does nothing, never opens a window
    $env:CCTOAST_EXT_GLOB = Join-Path $work 'no-such-ext-*'
    $uriA = New-ToastLaunchUri $target
    powershell -ExecutionPolicy Bypass -File $handler $uriA | Out-Null
    Assert-True (-not (Test-Path $log)) "no extension + no window: handler never launches code (no spurious window)"

    # --- Part B: extension present + pids -> drops focus-request file, still never calls code
    $reqFile = Join-Path $work 'focus.json'
    $extDir = Join-Path $work 'claude-toast.terminal-focus-9.9.9'
    New-Item -ItemType Directory -Path $extDir | Out-Null
    $env:CCTOAST_EXT_GLOB = Join-Path $work 'claude-toast.terminal-focus-*'
    $env:CCTOAST_FOCUS_FILE = $reqFile
    $uriB = New-ToastLaunchUri $target 'cctoast' '111,222,33692'
    powershell -ExecutionPolicy Bypass -File $handler $uriB | Out-Null

    Assert-True (Test-Path $reqFile) "extension path: handler wrote the focus-request file"
    $req = Get-Content $reqFile -Raw | ConvertFrom-Json
    Assert-Equal $req.pids '111,222,33692' "request file carries the pid chain"
    Assert-True ($req.ts -gt 0) "request file carries a timestamp"
    Assert-True (-not (Test-Path $log)) "extension path: handler never launches code"

    Write-Host "handler.tests PASSED"
}
finally {
    Remove-Item Env:\CCTOAST_EXT_GLOB -ErrorAction SilentlyContinue
    Remove-Item Env:\CCTOAST_FOCUS_FILE -ErrorAction SilentlyContinue
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}
