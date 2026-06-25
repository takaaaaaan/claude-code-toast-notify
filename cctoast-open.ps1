param([string]$Uri)
# Protocol handler for cctoast://open?path=<encoded cwd>.
# Brings the EXISTING VS Code window for that workspace to the foreground,
# WITHOUT opening a new window. Only if no matching window is found does it
# fall back to launching `code`. Never throws visibly.
$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'lib\cctoast-lib.ps1')

$cwd = ConvertFrom-ToastLaunchUri $Uri
if ([string]::IsNullOrWhiteSpace($cwd) -or -not (Test-Path -LiteralPath $cwd)) { exit 0 }
$leaf = Split-Path -Leaf $cwd

Add-Type -Namespace Native -Name Win -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll")] public static extern bool SetForegroundWindow(System.IntPtr hWnd);
[System.Runtime.InteropServices.DllImport("user32.dll")] public static extern bool ShowWindow(System.IntPtr hWnd, int nCmdShow);
[System.Runtime.InteropServices.DllImport("user32.dll")] public static extern bool IsIconic(System.IntPtr hWnd);
[System.Runtime.InteropServices.DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, System.UIntPtr dwExtraInfo);
'@

function Find-CodeWindow([string]$Leaf) {
    Get-Process -Name 'Code' -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -match [regex]::Escape($Leaf) } |
        Select-Object -First 1
}

function Set-Foreground([System.IntPtr]$Handle) {
    if ([Native.Win]::IsIconic($Handle)) { [Native.Win]::ShowWindow($Handle, 9) | Out-Null }  # SW_RESTORE
    # A synthetic ALT tap clears the OS foreground-lock so SetForegroundWindow is honored.
    [Native.Win]::keybd_event(0xA4, 0, 0, [System.UIntPtr]::Zero)   # ALT down
    [Native.Win]::keybd_event(0xA4, 0, 2, [System.UIntPtr]::Zero)   # ALT up
    [Native.Win]::SetForegroundWindow($Handle) | Out-Null
}

# 1) prefer an already-open VS Code window for this workspace
$win = Find-CodeWindow $leaf

# 2) only if none is open, launch it (a new window is acceptable here)
if (-not $win) {
    & code "$cwd" 2>$null
    for ($i = 0; $i -lt 12 -and -not $win; $i++) {
        Start-Sleep -Milliseconds 250
        $win = Find-CodeWindow $leaf
    }
}

if ($win) { Set-Foreground $win.MainWindowHandle }
exit 0
