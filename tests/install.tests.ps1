$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\assert.ps1"
$repo = Split-Path -Parent $PSScriptRoot
$tmp = Join-Path $env:TEMP ('cctoast-install-' + [guid]::NewGuid().ToString('N'))
$appId = 'Claude.Code.ToastNotify.Test'
$scheme = 'cctoasttest'
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
'{ "theme":"dark", "hooks": { "Stop": [ { "hooks":[ {"type":"command","command":"echo other"} ] } ] } }' |
    Set-Content (Join-Path $tmp 'settings.json') -Encoding utf8

& "$repo\install.ps1" -Lang ja -ClaudeDir $tmp -AppId $appId -Scheme $scheme | Out-Null
& "$repo\install.ps1" -Lang ko -ClaudeDir $tmp -AppId $appId -Scheme $scheme | Out-Null  # idempotency

Assert-True (Test-Path (Join-Path $tmp 'claude-hook-toast.ps1')) "hook script copied"
Assert-True (Test-Path (Join-Path $tmp 'cctoast-open.ps1')) "handler copied"
Assert-True (Test-Path (Join-Path $tmp 'lib\cctoast-lib.ps1')) "lib copied"
Assert-True (Test-Path (Join-Path $tmp 'icon.png')) "icon copied"
Assert-True (Test-Path "HKCU:\Software\Classes\AppUserModelId\$appId") "AUMID registered"
Assert-True (Test-Path "HKCU:\Software\Classes\$scheme\shell\open\command") "protocol registered"

$s = Get-Content (Join-Path $tmp 'settings.json') -Raw | ConvertFrom-Json
Assert-Equal $s.theme 'dark' "unrelated setting preserved"
$stop = @($s.hooks.Stop | Where-Object { $_.hooks[0].command -match 'claude-hook-toast' })
Assert-Equal $stop.Count 1 "exactly one of our Stop hooks (idempotent across re-run)"
Assert-True ($stop[0].hooks[0].command -match ' ko$') "latest lang wins"

# cleanup
Remove-Item "HKCU:\Software\Classes\AppUserModelId\$appId" -Recurse -Force
Remove-Item "HKCU:\Software\Classes\$scheme" -Recurse -Force
Remove-Item $tmp -Recurse -Force
Write-Host "install.tests PASSED"
