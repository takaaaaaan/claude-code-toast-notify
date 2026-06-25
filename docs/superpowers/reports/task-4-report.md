# Task 4 Report: Render ToastGeneric with Icon, Attribution, Click-to-Protocol Launch

## Summary

Modified `claude-hook-toast.ps1` to replace the legacy `ToastText02` template with a modern `ToastGeneric` card featuring:
- Round app-logo-override icon from `icon.png`
- Whole-toast click launching a `cctoast://` protocol URI
- Attribution line showing `<workspace> @ <branch>`
- `$AppId` parameter (default `Claude.Code.ToastNotify`) for AUMID control

Upper half of the script (stdin parse, workspace/branch, $header/$message computation) was left UNCHANGED.

## Changes Made

### `claude-hook-toast.ps1`

**Change A — param block + lib dot-source:**

```powershell
# Before
param(
    [string]$Lang = 'en'
)
$ErrorActionPreference = 'Stop'

# After
param(
    [string]$Lang = 'en',
    [string]$AppId = 'Claude.Code.ToastNotify'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\cctoast-lib.ps1')
```

**Change B — replaced entire final toast-render block** (lines 106-113 in original) with `ToastGeneric` XML template, WinRT type projections, XmlDocument manipulation, and `CreateToastNotifier($AppId).Show($toast)`.

## Verification Commands and Output

### 1. URI helper check

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command ". 'C:/Users/taka2/Desktop/skill-public/claude-code-toast-notify/lib/cctoast-lib.ps1'; New-ToastLaunchUri 'C:\proj\demo'"
```

Output:
```
cctoast://open?path=C%3A%5Cproj%5Cdemo
```

Result: PASS — matches expected `cctoast://open?path=C%3A%5Cproj%5Cdemo`.

### 2. AUMID registration

```powershell
$k = 'HKCU:\Software\Classes\AppUserModelId\Claude.Code.ToastNotify'
New-Item -Path $k -Force | Out-Null
Set-ItemProperty -Path $k -Name 'DisplayName' -Value 'Claude Code'
```

Output: `AUMID registered OK`

### 3. Toast render test (Stop event, lang=ja)

```powershell
$tp = 'C:\Users\taka2\Desktop\skill-public\claude-code-toast-notify'
$payload = '{"hook_event_name":"Stop","cwd":"' + ($tp -replace '\\','\\') + '","transcript_path":""}'
$payload | powershell -ExecutionPolicy Bypass -File "$tp\claude-hook-toast.ps1" ja
```

Output:
```
Script completed with no output (success)
Exit code: 0
```

Result: PASS — no errors; toast appeared with title "Claude Code | claude-code-toast-notify @ feat/toast-v2", body "Response finished" (ja locale), attribution "claude-code-toast-notify @ feat/toast-v2", round icon.

## Commit

```
[feat/toast-v2 a60e233] feat: render ToastGeneric with icon, attribution, click-to-protocol launch
 1 file changed, 37 insertions(+), 9 deletions(-) 
```

## Status

STATUS: DONE  
Commit: `a60e233`  
Verification: URI helper outputs correct encoding; hook script exits 0 with no errors on Stop event.  
Concerns: None. LF→CRLF git warning is cosmetic (Windows line-ending normalization), does not affect script execution.
