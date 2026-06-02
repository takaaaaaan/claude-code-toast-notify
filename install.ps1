param(
    [ValidateSet('en', 'ja', 'ko')]
    [string]$Lang = 'en',
    [string]$ClaudeDir = (Join-Path $env:USERPROFILE '.claude')
)

# Installer for the Claude Code toast notification hook.
# - Copies claude-hook-toast.ps1 + messages.json into <ClaudeDir>
# - Merges Notification/Stop hooks into <ClaudeDir>/settings.json
#   using an absolute, forward-slash path resolved at install time, so the
#   hook command works from git bash, PowerShell, or cmd with no variable
#   expansion. Existing settings are preserved; re-running is idempotent.

$ErrorActionPreference = 'Stop'
$srcDir = $PSScriptRoot

# 1) copy files
if (-not (Test-Path -LiteralPath $ClaudeDir)) {
    New-Item -ItemType Directory -Path $ClaudeDir -Force | Out-Null
}
Copy-Item -LiteralPath (Join-Path $srcDir 'claude-hook-toast.ps1') -Destination $ClaudeDir -Force
Copy-Item -LiteralPath (Join-Path $srcDir 'messages.json')         -Destination $ClaudeDir -Force

# 2) build the hook command with a resolved absolute path (forward slashes)
$ps1Path  = (Join-Path $ClaudeDir 'claude-hook-toast.ps1') -replace '\\', '/'
$command  = "powershell -ExecutionPolicy Bypass -File `"$ps1Path`" $Lang"

# 3) load (or create) settings.json
$settingsPath = Join-Path $ClaudeDir 'settings.json'
if (Test-Path -LiteralPath $settingsPath) {
    $sr = New-Object System.IO.StreamReader($settingsPath, [System.Text.Encoding]::UTF8)
    $text = $sr.ReadToEnd(); $sr.Close()
    if ([string]::IsNullOrWhiteSpace($text)) { $settings = [PSCustomObject]@{} }
    else { $settings = $text | ConvertFrom-Json }
    # backup before modifying
    Copy-Item -LiteralPath $settingsPath -Destination "$settingsPath.bak" -Force
} else {
    $settings = [PSCustomObject]@{}
}

# 4) merge a hook for one event, removing any prior entry that references our
#    script (handles upgrades / re-runs without duplicating notifications)
function Set-Hook($settings, $eventName, $command) {
    if (-not $settings.PSObject.Properties['hooks']) {
        $settings | Add-Member -NotePropertyName 'hooks' -NotePropertyValue ([PSCustomObject]@{})
    }
    $hooks = $settings.hooks
    $kept = @()
    if ($hooks.PSObject.Properties[$eventName]) {
        foreach ($group in @($hooks.$eventName)) {
            $refsOurs = $false
            foreach ($h in @($group.hooks)) {
                if ($h.command -and $h.command -match 'claude-hook-toast\.ps1') { $refsOurs = $true }
            }
            if (-not $refsOurs) { $kept += $group }
        }
    }
    $kept += [PSCustomObject]@{ hooks = @([PSCustomObject]@{ type = 'command'; command = $command }) }
    if ($hooks.PSObject.Properties[$eventName]) { $hooks.$eventName = @($kept) }
    else { $hooks | Add-Member -NotePropertyName $eventName -NotePropertyValue @($kept) }
}

Set-Hook $settings 'Notification' $command
Set-Hook $settings 'Stop'         $command

# 5) write settings.json back as UTF-8 (no BOM)
$out = $settings | ConvertTo-Json -Depth 20
[System.IO.File]::WriteAllText($settingsPath, $out, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "Installed toast hook (lang=$Lang)."
Write-Host "  script   : $ps1Path"
Write-Host "  settings : $settingsPath"
Write-Host "Open /hooks in Claude Code once, or restart, to load the new hooks."
