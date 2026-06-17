param(
    [string]$ClaudeDir = (Join-Path $env:USERPROFILE '.claude'),
    [string]$AppId = 'Claude.Code.ToastNotify',
    [string]$Scheme = 'cctoast'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\cctoast-lib.ps1')

$settingsPath = Join-Path $ClaudeDir 'settings.json'
if (Test-Path -LiteralPath $settingsPath) {
    $sr = New-Object System.IO.StreamReader($settingsPath, [System.Text.Encoding]::UTF8)
    $text = $sr.ReadToEnd(); $sr.Close()
    if (-not [string]::IsNullOrWhiteSpace($text)) {
        $settings = $text | ConvertFrom-Json
        Copy-Item -LiteralPath $settingsPath -Destination "$settingsPath.bak" -Force
        Remove-ToastHook $settings 'Notification'
        Remove-ToastHook $settings 'Stop'
        $out = $settings | ConvertTo-Json -Depth 20
        [System.IO.File]::WriteAllText($settingsPath, $out, (New-Object System.Text.UTF8Encoding($false)))
    }
}

foreach ($f in @('claude-hook-toast.ps1', 'cctoast-open.ps1', 'messages.json', 'icon.png', 'lib\cctoast-lib.ps1')) {
    $p = Join-Path $ClaudeDir $f
    if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force }
}
$libDir = Join-Path $ClaudeDir 'lib'
if ((Test-Path $libDir) -and -not (Get-ChildItem $libDir -Force)) { Remove-Item $libDir -Force }

foreach ($key in @("HKCU:\Software\Classes\AppUserModelId\$AppId", "HKCU:\Software\Classes\$Scheme")) {
    if (Test-Path $key) { Remove-Item $key -Recurse -Force }
}
Write-Host "Uninstalled toast hook v2 from $ClaudeDir."
