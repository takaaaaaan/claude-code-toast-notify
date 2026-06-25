param(
    [ValidateSet('en', 'ja', 'ko')]
    [string]$Lang = 'en',
    [string]$ClaudeDir = (Join-Path $env:USERPROFILE '.claude'),
    [string]$AppId = 'Claude.Code.ToastNotify',
    [string]$Scheme = 'cctoast'
)
$ErrorActionPreference = 'Stop'
$srcDir = $PSScriptRoot
. (Join-Path $srcDir 'lib\cctoast-lib.ps1')

# 1) copy files (preserve lib/ subdir)
if (-not (Test-Path -LiteralPath $ClaudeDir)) { New-Item -ItemType Directory -Path $ClaudeDir -Force | Out-Null }
if (-not (Test-Path -LiteralPath (Join-Path $ClaudeDir 'lib'))) { New-Item -ItemType Directory -Path (Join-Path $ClaudeDir 'lib') -Force | Out-Null }
Copy-Item (Join-Path $srcDir 'claude-hook-toast.ps1') $ClaudeDir -Force
Copy-Item (Join-Path $srcDir 'cctoast-open.ps1')      $ClaudeDir -Force
Copy-Item (Join-Path $srcDir 'messages.json')         $ClaudeDir -Force
Copy-Item (Join-Path $srcDir 'icon.png')              $ClaudeDir -Force
Copy-Item (Join-Path $srcDir 'lib\cctoast-lib.ps1')   (Join-Path $ClaudeDir 'lib') -Force

# 2) register custom AUMID (toast header shows "Claude Code" + icon)
$aumidKey = "HKCU:\Software\Classes\AppUserModelId\$AppId"
New-Item -Path $aumidKey -Force | Out-Null
Set-ItemProperty -Path $aumidKey -Name 'DisplayName' -Value 'Claude Code'
Set-ItemProperty -Path $aumidKey -Name 'IconUri' -Value (Join-Path $ClaudeDir 'icon.png')

# 3) register the cctoast: protocol -> handler
$handler = (Join-Path $ClaudeDir 'cctoast-open.ps1')
$schemeKey = "HKCU:\Software\Classes\$Scheme"
New-Item -Path $schemeKey -Force | Out-Null
Set-ItemProperty -Path $schemeKey -Name '(default)' -Value "URL:$Scheme protocol"
Set-ItemProperty -Path $schemeKey -Name 'URL Protocol' -Value ''
$cmdKey = "$schemeKey\shell\open\command"
New-Item -Path $cmdKey -Force | Out-Null
Set-ItemProperty -Path $cmdKey -Name '(default)' -Value "powershell -ExecutionPolicy Bypass -File `"$handler`" `"%1`""

# 4) merge hooks with an install-time absolute, forward-slash path
$ps1Path = (Join-Path $ClaudeDir 'claude-hook-toast.ps1') -replace '\\', '/'
$command = "powershell -ExecutionPolicy Bypass -File `"$ps1Path`" $Lang -AppId `"$AppId`" -Scheme `"$Scheme`""

$settingsPath = Join-Path $ClaudeDir 'settings.json'
if (Test-Path -LiteralPath $settingsPath) {
    $sr = New-Object System.IO.StreamReader($settingsPath, [System.Text.Encoding]::UTF8)
    $text = $sr.ReadToEnd(); $sr.Close()
    $settings = if ([string]::IsNullOrWhiteSpace($text)) { [PSCustomObject]@{} } else { $text | ConvertFrom-Json }
    Copy-Item -LiteralPath $settingsPath -Destination "$settingsPath.bak" -Force
} else { $settings = [PSCustomObject]@{} }

Set-ToastHook $settings 'Notification' $command
Set-ToastHook $settings 'Stop'         $command

$out = $settings | ConvertTo-Json -Depth 20
[System.IO.File]::WriteAllText($settingsPath, $out, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "Installed toast hook v2 (lang=$Lang)."
Write-Host "  scripts  : $ClaudeDir"
Write-Host "  AUMID    : $AppId"
Write-Host "  protocol : ${Scheme}://"
Write-Host "Open /hooks in Claude Code once, or restart, to load the new hooks."
