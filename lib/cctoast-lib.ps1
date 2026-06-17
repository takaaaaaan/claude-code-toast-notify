# Pure, side-effect-free helpers shared by the hook, handler, and installer.
# ASCII-only source (CP949 safety).

function New-ToastLaunchUri {
    param([string]$Cwd)
    $enc = [System.Uri]::EscapeDataString([string]$Cwd)
    return "cctoast://open?path=$enc"
}

function ConvertFrom-ToastLaunchUri {
    param([string]$Uri)
    if ($Uri -match 'path=([^&]+)') {
        return [System.Uri]::UnescapeDataString($Matches[1])
    }
    return $null
}

function Set-ToastHook {
    param($Settings, [string]$EventName, [string]$Command)
    if (-not $Settings.PSObject.Properties['hooks']) {
        $Settings | Add-Member -NotePropertyName 'hooks' -NotePropertyValue ([PSCustomObject]@{})
    }
    $hooks = $Settings.hooks
    $kept = @()
    if ($hooks.PSObject.Properties[$EventName]) {
        foreach ($group in @($hooks.$EventName)) {
            $refsOurs = $false
            foreach ($h in @($group.hooks)) {
                if ($h.command -and $h.command -match 'claude-hook-toast\.ps1') { $refsOurs = $true }
            }
            if (-not $refsOurs) { $kept += $group }
        }
    }
    $kept += [PSCustomObject]@{ hooks = @([PSCustomObject]@{ type = 'command'; command = $Command }) }
    if ($hooks.PSObject.Properties[$EventName]) { $hooks.$EventName = @($kept) }
    else { $hooks | Add-Member -NotePropertyName $EventName -NotePropertyValue @($kept) }
}

function Remove-ToastHook {
    param($Settings, [string]$EventName)
    if (-not $Settings.PSObject.Properties['hooks']) { return }
    $hooks = $Settings.hooks
    if (-not $hooks.PSObject.Properties[$EventName]) { return }
    $kept = @()
    foreach ($group in @($hooks.$EventName)) {
        $refsOurs = $false
        foreach ($h in @($group.hooks)) {
            if ($h.command -and $h.command -match 'claude-hook-toast\.ps1') { $refsOurs = $true }
        }
        if (-not $refsOurs) { $kept += $group }
    }
    if ($kept.Count -gt 0) { $hooks.$EventName = @($kept) }
    else { $hooks.PSObject.Properties.Remove($EventName) }
    if (@($hooks.PSObject.Properties).Count -eq 0) {
        $Settings.PSObject.Properties.Remove('hooks')
    }
}
