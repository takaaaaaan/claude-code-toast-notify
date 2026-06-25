param([string]$Uri)
# Protocol handler for cctoast://open?path=<encoded cwd>&pids=<chain>.
#
# Tab focus is driven by the companion VS Code extension via the ancestor PID
# chain (cwd-independent and correct even after `cd`). So when the extension is
# installed we ONLY drop the focus-request file and exit -- we never touch
# windows by cwd (the shell's cwd can differ from the VS Code workspace folder,
# which previously caused a spurious `code -n` window to open).
#
# Without the extension we fall back to a best-effort window raise by matching
# the workspace name in the window title. We never launch a new window.
# Never throws visibly.
$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'lib\cctoast-lib.ps1')

$cwd = ConvertFrom-ToastLaunchUri $Uri
if ([string]::IsNullOrWhiteSpace($cwd) -or -not (Test-Path -LiteralPath $cwd)) { exit 0 }
$leaf = Split-Path -Leaf $cwd

# Drop a focus request for the companion extension. Every VS Code window watches
# this file; the one that owns Claude's terminal focuses the exact tab by PID.
$pids = Get-ToastLaunchPids $Uri
if ($pids) {
    try {
        $reqFile = if ($env:CCTOAST_FOCUS_FILE) { $env:CCTOAST_FOCUS_FILE } else { Join-Path $PSScriptRoot '.cctoast-focus.json' }
        $ts = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        $req = '{"pids":"' + $pids + '","ts":' + $ts + '}'
        [System.IO.File]::WriteAllText($reqFile, $req, (New-Object System.Text.UTF8Encoding($false)))
    } catch { }
}

# If the extension is installed it handles tab focus (and window reveal); the
# handler must NOT do any cwd-based window logic (cwd != workspace folder).
$extGlob = if ($env:CCTOAST_EXT_GLOB) { $env:CCTOAST_EXT_GLOB } else { Join-Path $HOME '.vscode\extensions\claude-toast.terminal-focus-*' }
if (Test-Path $extGlob) { exit 0 }

# No extension: best-effort raise of an already-open window whose title carries
# the workspace name. Never opens a new window.
Add-Type -TypeDefinition @'
using System;
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
                return false;
            }
            return true;
        }, IntPtr.Zero);
        return found;
    }

    public static void Focus(IntPtr h) {
        if (IsIconic(h)) ShowWindow(h, 9); // SW_RESTORE
        keybd_event(0xA4, 0, 0, UIntPtr.Zero);
        keybd_event(0xA4, 0, 2, UIntPtr.Zero);
        SetForegroundWindow(h);
    }
}
'@

$h = [CctoastWin]::Find($leaf)
if ($h -ne [System.IntPtr]::Zero) { [CctoastWin]::Focus($h) }
exit 0
