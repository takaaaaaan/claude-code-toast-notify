param([string]$Uri)
# Protocol handler for cctoast://open?path=<encoded cwd>.
# Focuses/opens the VS Code window for that workspace. Never throws visibly.
$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'lib\cctoast-lib.ps1')

$cwd = ConvertFrom-ToastLaunchUri $Uri
if ([string]::IsNullOrWhiteSpace($cwd) -or -not (Test-Path -LiteralPath $cwd)) { exit 0 }

# 1) open/reuse the VS Code window for this folder
& code --reuse-window "$cwd" 2>$null

# 2) best-effort: bring a matching VS Code window to the foreground
try {
    $leaf = Split-Path -Leaf $cwd
    Add-Type -Namespace Native -Name Win -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern bool SetForegroundWindow(System.IntPtr hWnd);
'@
    Start-Sleep -Milliseconds 400
    $p = Get-Process -Name 'Code' -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowTitle -match [regex]::Escape($leaf) -and $_.MainWindowTitle -match 'Visual Studio Code' } |
        Select-Object -First 1
    if ($p) { [Native.Win]::SetForegroundWindow($p.MainWindowHandle) | Out-Null }
} catch { }
exit 0
