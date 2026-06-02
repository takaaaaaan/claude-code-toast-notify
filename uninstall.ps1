param(
    [string]$ClaudeDir = (Join-Path $env:USERPROFILE '.claude')
)

# Uninstaller: removes the toast hooks from settings.json and deletes the
# installed script + messages.json. Other settings are preserved.

$ErrorActionPreference = 'Stop'
$settingsPath = Join-Path $ClaudeDir 'settings.json'

if (Test-Path -LiteralPath $settingsPath) {
    $sr = New-Object System.IO.StreamReader($settingsPath, [System.Text.Encoding]::UTF8)
    $text = $sr.ReadToEnd(); $sr.Close()
    if (-not [string]::IsNullOrWhiteSpace($text)) {
        $settings = $text | ConvertFrom-Json
        Copy-Item -LiteralPath $settingsPath -Destination "$settingsPath.bak" -Force

        if ($settings.PSObject.Properties['hooks']) {
            $hooks = $settings.hooks
            foreach ($eventName in @('Notification', 'Stop')) {
                if (-not $hooks.PSObject.Properties[$eventName]) { continue }
                $kept = @()
                foreach ($group in @($hooks.$eventName)) {
                    $refsOurs = $false
                    foreach ($h in @($group.hooks)) {
                        if ($h.command -and $h.command -match 'claude-hook-toast\.ps1') { $refsOurs = $true }
                    }
                    if (-not $refsOurs) { $kept += $group }
                }
                if ($kept.Count -gt 0) { $hooks.$eventName = @($kept) }
                else { $hooks.PSObject.Properties.Remove($eventName) }
            }
            # drop the hooks object entirely if it is now empty
            if (@($hooks.PSObject.Properties).Count -eq 0) {
                $settings.PSObject.Properties.Remove('hooks')
            }
        }

        $out = $settings | ConvertTo-Json -Depth 20
        [System.IO.File]::WriteAllText($settingsPath, $out, (New-Object System.Text.UTF8Encoding($false)))
    }
}

foreach ($f in @('claude-hook-toast.ps1', 'messages.json')) {
    $p = Join-Path $ClaudeDir $f
    if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force }
}

Write-Host "Uninstalled toast hook from $ClaudeDir."
