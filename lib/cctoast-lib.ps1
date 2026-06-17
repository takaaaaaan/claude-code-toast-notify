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
