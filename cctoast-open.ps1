param([string]$Uri)
# Protocol handler for cctoast://open?path=<encoded cwd>.
# Brings the EXISTING VS Code window for that workspace to the foreground,
# WITHOUT opening a new window. VS Code (Electron) keeps all windows under a
# single process, so Get-Process exposes only one window; we enumerate every
# top-level window with EnumWindows and match the one whose title carries the
# workspace name. Only if none is open does it fall back to launching `code`.
# Never throws visibly.
$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'lib\cctoast-lib.ps1')

$cwd = ConvertFrom-ToastLaunchUri $Uri
if ([string]::IsNullOrWhiteSpace($cwd) -or -not (Test-Path -LiteralPath $cwd)) { exit 0 }
$leaf = Split-Path -Leaf $cwd

# If the companion VS Code extension is installed, hand off to it: it focuses
# the EXACT terminal tab (by matching the ancestor PID chain) and brings the
# window forward. Without the extension, fall through to window-level focus.
$pids = Get-ToastLaunchPids $Uri
$extInstalled = Test-Path (Join-Path $HOME '.vscode\extensions\claude-toast.terminal-focus-*')
if ($extInstalled -and $pids) {
    Start-Process "vscode://claude-toast.terminal-focus/focus?pids=$pids"
    exit 0
}

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public class CctoastWin {
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr p);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] static extern int GetWindowTextLength(IntPtr h);
    [DllImport("user32.dll")] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
    [DllImport("user32.dll")] public static extern void keybd_event(byte k, byte s, uint f, UIntPtr e);
    delegate bool EnumProc(IntPtr h, IntPtr p);

    public static IntPtr Find(string leaf) {
        IntPtr found = IntPtr.Zero;
        EnumWindows((h, p) => {
            if (!IsWindowVisible(h)) return true;
            int len = GetWindowTextLength(h);
            if (len <= 0) return true;
            StringBuilder sb = new StringBuilder(len + 1);
            GetWindowText(h, sb, sb.Capacity);
            string t = sb.ToString();
            if (t.IndexOf("Visual Studio Code", StringComparison.OrdinalIgnoreCase) >= 0 &&
                t.IndexOf(leaf, StringComparison.OrdinalIgnoreCase) >= 0) {
                found = h;
                return false; // stop at first match
            }
            return true;
        }, IntPtr.Zero);
        return found;
    }

    public static void Focus(IntPtr h) {
        if (IsIconic(h)) ShowWindow(h, 9); // SW_RESTORE
        // synthetic ALT tap clears the OS foreground-lock so the raise is honored
        keybd_event(0xA4, 0, 0, UIntPtr.Zero);
        keybd_event(0xA4, 0, 2, UIntPtr.Zero);
        SetForegroundWindow(h);
    }
}
'@

# 1) prefer an already-open VS Code window for this workspace
$h = [CctoastWin]::Find($leaf)

# 2) only if none is open, launch it in a NEW window (do not hijack another)
if ($h -eq [System.IntPtr]::Zero) {
    & code -n "$cwd" 2>$null
    for ($i = 0; $i -lt 12 -and $h -eq [System.IntPtr]::Zero; $i++) {
        Start-Sleep -Milliseconds 250
        $h = [CctoastWin]::Find($leaf)
    }
}

if ($h -ne [System.IntPtr]::Zero) { [CctoastWin]::Focus($h) }
exit 0
