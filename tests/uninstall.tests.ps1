$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\assert.ps1"
$repo = Split-Path -Parent $PSScriptRoot
$tmp = Join-Path $env:TEMP ('cctoast-uninstall-' + [guid]::NewGuid().ToString('N'))
$appId = 'Claude.Code.ToastNotify.Test'
$scheme = 'cctoasttest'
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
'{ "theme":"dark" }' | Set-Content (Join-Path $tmp 'settings.json') -Encoding utf8

try {
    & "$repo\install.ps1" -Lang en -ClaudeDir $tmp -AppId $appId -Scheme $scheme | Out-Null
    & "$repo\uninstall.ps1" -ClaudeDir $tmp -AppId $appId -Scheme $scheme | Out-Null

    Assert-True (-not (Test-Path (Join-Path $tmp 'claude-hook-toast.ps1'))) "hook script removed"
    Assert-True (-not (Test-Path (Join-Path $tmp 'cctoast-open.ps1'))) "handler removed"
    Assert-True (-not (Test-Path "HKCU:\Software\Classes\AppUserModelId\$appId")) "AUMID removed"
    Assert-True (-not (Test-Path "HKCU:\Software\Classes\$scheme")) "protocol removed"
    $s = Get-Content (Join-Path $tmp 'settings.json') -Raw | ConvertFrom-Json
    Assert-Equal $s.theme 'dark' "unrelated setting preserved"
    Assert-True (-not $s.PSObject.Properties['hooks']) "our hooks fully removed"
    Write-Host "uninstall.tests PASSED"
} finally {
    Remove-Item "HKCU:\Software\Classes\AppUserModelId\$appId" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "HKCU:\Software\Classes\$scheme" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
