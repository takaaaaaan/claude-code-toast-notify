# Toast v2 — Click-to-VS-Code + Modern UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the Windows toast notifier so the whole toast is a modern `ToastGeneric` card that, when clicked, brings the matching VS Code workspace window to the foreground.

**Architecture:** Pure helpers (URI build/parse, settings-hook merge) live in a sourced `lib/cctoast-lib.ps1` so they are unit-testable. `claude-hook-toast.ps1` renders a `ToastGeneric` toast whose `launch` is a `cctoast://` protocol URI carrying the cwd. A registered HKCU protocol handler (`cctoast-open.ps1`) decodes the cwd and runs `code --reuse-window` plus a best-effort Win32 foreground. `install.ps1` copies files, registers a custom AUMID + the `cctoast:` protocol in HKCU, and merges the hooks.

**Tech Stack:** Windows PowerShell 5.1, WinRT toast APIs (`Windows.UI.Notifications`), HKCU registry, VS Code `code` CLI, plain-PowerShell test scripts (no Pester dependency).

## Global Constraints

- `claude-hook-toast.ps1`, `cctoast-open.ps1`, and `lib/cctoast-lib.ps1` source MUST be **ASCII-only**. Windows PowerShell 5.1 reads BOM-less `.ps1` in the system ANSI code page (CP949 here); non-ASCII literals corrupt parsing. All human-language text lives in `messages.json` (UTF-8) or the hook payload, read explicitly as UTF-8.
- Registry writes are **HKCU only** (no admin).
- Hook commands written into `settings.json` use an **install-time absolute, forward-slash path** with no `%USERPROFILE%` / `$env:` expansion (must run from git bash, PowerShell, or cmd).
- Custom AUMID id: `Claude.Code.ToastNotify` (DisplayName `Claude Code`). Protocol scheme: `cctoast`. Both are parameters with these defaults so tests can pass throwaway names.
- All installer/handler/uninstaller functions are idempotent and swallow non-fatal errors (logged, never a visible crash).
- `settings.json` is read/written as UTF-8 without BOM; back up to `settings.json.bak` before modifying.

---

### Task 1: Pure helper library — protocol URI build/parse

**Files:**
- Create: `lib/cctoast-lib.ps1`
- Create: `tests/assert.ps1`
- Test: `tests/uri.tests.ps1`

**Interfaces:**
- Produces: `New-ToastLaunchUri([string]$Cwd) -> [string]` returns `cctoast://open?path=<percent-encoded cwd>`. `ConvertFrom-ToastLaunchUri([string]$Uri) -> [string]` returns the decoded cwd (or `$null` if no `path`).

- [ ] **Step 1: Write the tiny assert helper**

Create `tests/assert.ps1`:

```powershell
function Assert-Equal($actual, $expected, $msg) {
    if ($actual -ne $expected) {
        throw "ASSERT FAILED: $msg`n  expected: [$expected]`n  actual:   [$actual]"
    }
    Write-Host "  ok: $msg"
}
function Assert-True($cond, $msg) {
    if (-not $cond) { throw "ASSERT FAILED: $msg" }
    Write-Host "  ok: $msg"
}
```

- [ ] **Step 2: Write the failing test**

Create `tests/uri.tests.ps1`:

```powershell
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\assert.ps1"
. "$PSScriptRoot\..\lib\cctoast-lib.ps1"

$cwd = 'C:\Users\taka2\Desktop\final-project\metabolic-twin-fe'
$uri = New-ToastLaunchUri $cwd
Assert-True ($uri -like 'cctoast://open?path=*') "uri has scheme/prefix"
Assert-True ($uri -notmatch '[\\ ]') "uri is percent-encoded (no raw backslash/space)"
Assert-Equal (ConvertFrom-ToastLaunchUri $uri) $cwd "roundtrip restores cwd exactly"
Assert-Equal (ConvertFrom-ToastLaunchUri 'cctoast://open') $null "missing path -> null"
Write-Host "uri.tests PASSED"
```

- [ ] **Step 3: Run test to verify it fails**

Run: `powershell -ExecutionPolicy Bypass -File tests/uri.tests.ps1`
Expected: FAIL — `New-ToastLaunchUri` not recognized (lib is empty/missing).

- [ ] **Step 4: Write minimal implementation**

Create `lib/cctoast-lib.ps1`:

```powershell
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
```

- [ ] **Step 5: Run test to verify it passes**

Run: `powershell -ExecutionPolicy Bypass -File tests/uri.tests.ps1`
Expected: PASS — prints `uri.tests PASSED`.

- [ ] **Step 6: Commit**

```bash
git add lib/cctoast-lib.ps1 tests/assert.ps1 tests/uri.tests.ps1
git commit -m "feat: add cctoast protocol uri helpers with tests"
```

---

### Task 2: Move settings-hook merge into the library

**Files:**
- Modify: `lib/cctoast-lib.ps1` (append `Set-ToastHook`, `Remove-ToastHook`)
- Test: `tests/hooks.tests.ps1`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: `Set-ToastHook($Settings, [string]$EventName, [string]$Command)` mutates the `[PSCustomObject]$Settings` in place, ensuring exactly one hook group whose command references `claude-hook-toast.ps1` exists for `$EventName` (replaces any prior one). `Remove-ToastHook($Settings, [string]$EventName)` drops all groups referencing `claude-hook-toast.ps1` and removes the event/`hooks` property if left empty.

- [ ] **Step 1: Write the failing test**

Create `tests/hooks.tests.ps1`:

```powershell
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\assert.ps1"
. "$PSScriptRoot\..\lib\cctoast-lib.ps1"

# starts with an unrelated hook that must be preserved
$json = '{ "hooks": { "Stop": [ { "hooks": [ { "type":"command","command":"echo other" } ] } ] } }'
$s = $json | ConvertFrom-Json

Set-ToastHook $s 'Stop' 'powershell -File "C:/x/claude-hook-toast.ps1" ja'
Set-ToastHook $s 'Stop' 'powershell -File "C:/x/claude-hook-toast.ps1" ko'  # re-run -> replace
Set-ToastHook $s 'Notification' 'powershell -File "C:/x/claude-hook-toast.ps1" ko'

$stop = @($s.hooks.Stop)
Assert-Equal $stop.Count 2 "Stop keeps unrelated hook + exactly one of ours"
$ours = @($stop | Where-Object { $_.hooks[0].command -match 'claude-hook-toast' })
Assert-Equal $ours.Count 1 "exactly one of our Stop hooks (idempotent)"
Assert-True ($ours[0].hooks[0].command -match ' ko$') "latest command wins (ko)"

Remove-ToastHook $s 'Stop'
Remove-ToastHook $s 'Notification'
$stop2 = @($s.hooks.Stop)
Assert-Equal $stop2.Count 1 "Stop retains only the unrelated hook after removal"
Assert-True (-not $s.hooks.PSObject.Properties['Notification']) "empty Notification event removed"
Write-Host "hooks.tests PASSED"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -ExecutionPolicy Bypass -File tests/hooks.tests.ps1`
Expected: FAIL — `Set-ToastHook` not recognized.

- [ ] **Step 3: Write minimal implementation**

Append to `lib/cctoast-lib.ps1`:

```powershell
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -ExecutionPolicy Bypass -File tests/hooks.tests.ps1`
Expected: PASS — prints `hooks.tests PASSED`.

- [ ] **Step 5: Commit**

```bash
git add lib/cctoast-lib.ps1 tests/hooks.tests.ps1
git commit -m "feat: move idempotent hook merge/remove into lib with tests"
```

---

### Task 3: Generate the toast icon asset

**Files:**
- Create: `tools/make-icon.ps1`
- Create: `icon.png` (generated output, committed)

**Interfaces:**
- Produces: `icon.png` — a 256x256 PNG used as the toast `appLogoOverride`.

- [ ] **Step 1: Write the icon generator**

Create `tools/make-icon.ps1`:

```powershell
param([string]$Out = (Join-Path $PSScriptRoot '..\icon.png'))
Add-Type -AssemblyName System.Drawing
$size = 256
$bmp = New-Object System.Drawing.Bitmap $size, $size
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.Clear([System.Drawing.Color]::Transparent)
$bg = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 209, 102, 76)) # claude-ish clay
$g.FillEllipse($bg, 8, 8, $size-16, $size-16)
$font = New-Object System.Drawing.Font 'Segoe UI', 150, ([System.Drawing.FontStyle]::Bold)
$fg = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
$fmt = New-Object System.Drawing.StringFormat
$fmt.Alignment = 'Center'; $fmt.LineAlignment = 'Center'
$g.DrawString('C', $font, $fg, (New-Object System.Drawing.RectangleF 0,0,$size,$size), $fmt)
$g.Dispose()
$full = [System.IO.Path]::GetFullPath($Out)
$bmp.Save($full, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Host "wrote $full"
```

- [ ] **Step 2: Run it to produce the asset**

Run: `powershell -ExecutionPolicy Bypass -File tools/make-icon.ps1`
Expected: prints `wrote ...icon.png`.

- [ ] **Step 3: Verify the PNG is valid**

Run:
```powershell
powershell -NoProfile -Command "Add-Type -AssemblyName System.Drawing; $i=[System.Drawing.Image]::FromFile((Resolve-Path icon.png)); '{0}x{1}' -f $i.Width,$i.Height; $i.Dispose()"
```
Expected: prints `256x256`.

- [ ] **Step 4: Commit**

```bash
git add tools/make-icon.ps1 icon.png
git commit -m "feat: generate bundled toast icon"
```

---

### Task 4: Render a ToastGeneric toast with click-to-protocol launch

**Files:**
- Modify: `claude-hook-toast.ps1` (replace the toast-render section; add `-Lang` already present)
- Test: manual visual verification (toast rendering is not unit-testable)

**Interfaces:**
- Consumes: `New-ToastLaunchUri` from Task 1 (via `lib/cctoast-lib.ps1`).
- Produces: a toast shown under AUMID `Claude.Code.ToastNotify` whose `launch` is `cctoast://open?path=<cwd>`.

- [ ] **Step 1: Source the lib and add an AUMID parameter**

At the top of `claude-hook-toast.ps1`, change the `param` block and add the lib source (the script lives next to `lib/` after install):

```powershell
param(
    [string]$Lang = 'en',
    [string]$AppId = 'Claude.Code.ToastNotify'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\cctoast-lib.ps1')
```

- [ ] **Step 2: Replace the toast-render section**

Replace the final block (from `# --- show Windows toast ---` to end of file) with:

```powershell
# --- build launch URI + icon URI ------------------------------------------
$launchUri = if ($cwd) { New-ToastLaunchUri $cwd } else { 'cctoast://open' }
$iconPath  = Join-Path $PSScriptRoot 'icon.png'
$iconUri   = 'file:///' + ($iconPath -replace '\\', '/')
$attribution = if ($workspace) { if ($branch) { "$workspace @ $branch" } else { $workspace } } else { '' }

# --- show Windows toast (ToastGeneric) ------------------------------------
[void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
[void][Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType = WindowsRuntime]
[void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime]

$base = @'
<toast activationType="protocol" launch="">
  <visual>
    <binding template="ToastGeneric">
      <image placement="appLogoOverride" hint-crop="circle" src=""/>
      <text id="1"></text>
      <text id="2"></text>
      <text id="3" placement="attribution"></text>
    </binding>
  </visual>
</toast>
'@

$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
$xml.LoadXml($base)
$xml.DocumentElement.SetAttribute('launch', $launchUri)
$xml.SelectSingleNode('//image').SetAttribute('src', $iconUri)
$xml.SelectSingleNode('//text[@id="1"]').InnerText = $header
$xml.SelectSingleNode('//text[@id="2"]').InnerText = $message
$xml.SelectSingleNode('//text[@id="3"]').InnerText = $attribution

$toast = New-Object Windows.UI.Notifications.ToastNotification $xml
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId).Show($toast)
```

Note: `$header`, `$message`, `$workspace`, `$branch`, `$cwd` are computed by the existing upper half of the script and are unchanged.

- [ ] **Step 3: Register the AUMID temporarily, then render**

The AUMID must exist for the toast to display named. For this isolated test, register it inline first:

```powershell
$base = 'HKCU:\Software\Classes\AppUserModelId\Claude.Code.ToastNotify'
New-Item -Path $base -Force | Out-Null
Set-ItemProperty -Path $base -Name 'DisplayName' -Value 'Claude Code'
$tp = "C:/Users/taka2/Desktop/skill-public/claude-code-toast-notify"
Copy-Item "$tp/icon.png" "$tp/icon.png" -Force  # ensure present
'{"hook_event_name":"Stop","cwd":"' + ($tp -replace '/','\\') + '","transcript_path":""}' |
  powershell -ExecutionPolicy Bypass -File "$tp/claude-hook-toast.ps1" ja
```

Expected: a toast appears titled **Claude Code**, body `Response finished` (no transcript), attribution `claude-code-toast-notify @ <branch>`, with the round icon. No errors.

- [ ] **Step 4: Verify the launch URI is embedded**

Run (renders the XML to string without showing):
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command ". 'C:/Users/taka2/Desktop/skill-public/claude-code-toast-notify/lib/cctoast-lib.ps1'; New-ToastLaunchUri 'C:\proj\demo'"
```
Expected: prints `cctoast://open?path=C%3A%5Cproj%5Cdemo`.

- [ ] **Step 5: Commit**

```bash
git add claude-hook-toast.ps1
git commit -m "feat: render ToastGeneric with icon, attribution, click-to-protocol launch"
```

---

### Task 5: Protocol handler — open/focus the VS Code window

**Files:**
- Create: `cctoast-open.ps1`
- Test: `tests/handler.tests.ps1`

**Interfaces:**
- Consumes: `ConvertFrom-ToastLaunchUri` from Task 1.
- Produces: `cctoast-open.ps1 "<cctoast uri>"` decodes the cwd and invokes `code --reuse-window "<cwd>"`, then a best-effort Win32 foreground. Exits 0 even on failure.

- [ ] **Step 1: Write the failing test (fake `code` on PATH)**

Create `tests/handler.tests.ps1`:

```powershell
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\assert.ps1"

$work = Join-Path $env:TEMP ('cctoast-handler-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
$log = Join-Path $work 'code-args.txt'
# fake `code` that records its args
"@echo off`r`n>>`"$log`" echo %*" | Set-Content (Join-Path $work 'code.cmd') -Encoding ascii

$target = 'C:\Users\taka2\Desktop\final-project\metabolic-twin-fe'
. "$PSScriptRoot\..\lib\cctoast-lib.ps1"
$uri = New-ToastLaunchUri $target

$env:PATH = "$work;$env:PATH"
powershell -ExecutionPolicy Bypass -File "$PSScriptRoot\..\cctoast-open.ps1" $uri | Out-Null

Assert-True (Test-Path $log) "fake code was invoked"
$line = Get-Content $log -Raw
Assert-True ($line -match '--reuse-window') "code called with --reuse-window"
Assert-True ($line -match 'metabolic-twin-fe') "code called with the target path"
Remove-Item $work -Recurse -Force
Write-Host "handler.tests PASSED"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -ExecutionPolicy Bypass -File tests/handler.tests.ps1`
Expected: FAIL — `cctoast-open.ps1` does not exist.

- [ ] **Step 3: Write the handler**

Create `cctoast-open.ps1`:

```powershell
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -ExecutionPolicy Bypass -File tests/handler.tests.ps1`
Expected: PASS — prints `handler.tests PASSED`.

- [ ] **Step 5: Commit**

```bash
git add cctoast-open.ps1 tests/handler.tests.ps1
git commit -m "feat: cctoast protocol handler focuses VS Code workspace window"
```

---

### Task 6: Installer — copy files, register AUMID + protocol, merge hooks

**Files:**
- Modify: `install.ps1`
- Test: `tests/install.tests.ps1`

**Interfaces:**
- Consumes: `Set-ToastHook` (Task 2), the files from Tasks 1/3/4/5.
- Produces: a populated `<ClaudeDir>` (scripts + `lib/` + `icon.png` + `messages.json`), HKCU AUMID `Claude.Code.ToastNotify` (DisplayName + IconUri), HKCU protocol `cctoast` -> handler, and merged `Notification`/`Stop` hooks in `settings.json`.

- [ ] **Step 1: Rewrite install.ps1**

Replace `install.ps1` with:

```powershell
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
$command = "powershell -ExecutionPolicy Bypass -File `"$ps1Path`" $Lang"

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
```

- [ ] **Step 2: Write the failing test**

Create `tests/install.tests.ps1`:

```powershell
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\assert.ps1"
$repo = Split-Path -Parent $PSScriptRoot
$tmp = Join-Path $env:TEMP ('cctoast-install-' + [guid]::NewGuid().ToString('N'))
$appId = 'Claude.Code.ToastNotify.Test'
$scheme = 'cctoasttest'
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
'{ "theme":"dark", "hooks": { "Stop": [ { "hooks":[ {"type":"command","command":"echo other"} ] } ] } }' |
    Set-Content (Join-Path $tmp 'settings.json') -Encoding utf8

& "$repo\install.ps1" -Lang ja -ClaudeDir $tmp -AppId $appId -Scheme $scheme | Out-Null
& "$repo\install.ps1" -Lang ko -ClaudeDir $tmp -AppId $appId -Scheme $scheme | Out-Null  # idempotency

Assert-True (Test-Path (Join-Path $tmp 'claude-hook-toast.ps1')) "hook script copied"
Assert-True (Test-Path (Join-Path $tmp 'cctoast-open.ps1')) "handler copied"
Assert-True (Test-Path (Join-Path $tmp 'lib\cctoast-lib.ps1')) "lib copied"
Assert-True (Test-Path (Join-Path $tmp 'icon.png')) "icon copied"
Assert-True (Test-Path "HKCU:\Software\Classes\AppUserModelId\$appId") "AUMID registered"
Assert-True (Test-Path "HKCU:\Software\Classes\$scheme\shell\open\command") "protocol registered"

$s = Get-Content (Join-Path $tmp 'settings.json') -Raw | ConvertFrom-Json
Assert-Equal $s.theme 'dark' "unrelated setting preserved"
$stop = @($s.hooks.Stop | Where-Object { $_.hooks[0].command -match 'claude-hook-toast' })
Assert-Equal $stop.Count 1 "exactly one of our Stop hooks (idempotent across re-run)"
Assert-True ($stop[0].hooks[0].command -match ' ko$') "latest lang wins"

# cleanup
Remove-Item "HKCU:\Software\Classes\AppUserModelId\$appId" -Recurse -Force
Remove-Item "HKCU:\Software\Classes\$scheme" -Recurse -Force
Remove-Item $tmp -Recurse -Force
Write-Host "install.tests PASSED"
```

- [ ] **Step 3: Run test to verify it fails first, then passes**

Run: `powershell -ExecutionPolicy Bypass -File tests/install.tests.ps1`
Expected after Step 1 is in place: PASS — prints `install.tests PASSED`. (If run before Step 1's rewrite, it FAILS on missing copies/registry.)

- [ ] **Step 4: Commit**

```bash
git add install.ps1 tests/install.tests.ps1
git commit -m "feat: installer registers AUMID + cctoast protocol and copies v2 files"
```

---

### Task 7: Uninstaller — remove registry, files, and hooks

**Files:**
- Modify: `uninstall.ps1`
- Test: `tests/uninstall.tests.ps1`

**Interfaces:**
- Consumes: `Remove-ToastHook` (Task 2); the install layout (Task 6).
- Produces: a `<ClaudeDir>` with our files removed, HKCU AUMID + protocol keys removed, and our hooks dropped from `settings.json` (unrelated settings preserved).

- [ ] **Step 1: Rewrite uninstall.ps1**

Replace `uninstall.ps1` with:

```powershell
param(
    [string]$ClaudeDir = (Join-Path $env:USERPROFILE '.claude'),
    [string]$AppId = 'Claude.Code.ToastNotify',
    [string]$Scheme = 'cctoast'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\cctoast-lib.ps1')

$settingsPath = Join-Path $ClaudeDir 'settings.json'
if (Test-Path -LiteralPath $settingsPath) {
    $sr = New-Object System.IO.StreamReader($settingsPath, [System.Text.Encoding]::UTF8)
    $text = $sr.ReadToEnd(); $sr.Close()
    if (-not [string]::IsNullOrWhiteSpace($text)) {
        $settings = $text | ConvertFrom-Json
        Copy-Item -LiteralPath $settingsPath -Destination "$settingsPath.bak" -Force
        Remove-ToastHook $settings 'Notification'
        Remove-ToastHook $settings 'Stop'
        $out = $settings | ConvertTo-Json -Depth 20
        [System.IO.File]::WriteAllText($settingsPath, $out, (New-Object System.Text.UTF8Encoding($false)))
    }
}

foreach ($f in @('claude-hook-toast.ps1', 'cctoast-open.ps1', 'messages.json', 'icon.png', 'lib\cctoast-lib.ps1')) {
    $p = Join-Path $ClaudeDir $f
    if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force }
}
$libDir = Join-Path $ClaudeDir 'lib'
if ((Test-Path $libDir) -and -not (Get-ChildItem $libDir -Force)) { Remove-Item $libDir -Force }

foreach ($key in @("HKCU:\Software\Classes\AppUserModelId\$AppId", "HKCU:\Software\Classes\$Scheme")) {
    if (Test-Path $key) { Remove-Item $key -Recurse -Force }
}
Write-Host "Uninstalled toast hook v2 from $ClaudeDir."
```

- [ ] **Step 2: Write the test (install then uninstall)**

Create `tests/uninstall.tests.ps1`:

```powershell
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\assert.ps1"
$repo = Split-Path -Parent $PSScriptRoot
$tmp = Join-Path $env:TEMP ('cctoast-uninstall-' + [guid]::NewGuid().ToString('N'))
$appId = 'Claude.Code.ToastNotify.Test'
$scheme = 'cctoasttest'
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
'{ "theme":"dark" }' | Set-Content (Join-Path $tmp 'settings.json') -Encoding utf8

& "$repo\install.ps1" -Lang en -ClaudeDir $tmp -AppId $appId -Scheme $scheme | Out-Null
& "$repo\uninstall.ps1" -ClaudeDir $tmp -AppId $appId -Scheme $scheme | Out-Null

Assert-True (-not (Test-Path (Join-Path $tmp 'claude-hook-toast.ps1'))) "hook script removed"
Assert-True (-not (Test-Path (Join-Path $tmp 'cctoast-open.ps1'))) "handler removed"
Assert-True (-not (Test-Path "HKCU:\Software\Classes\AppUserModelId\$appId")) "AUMID removed"
Assert-True (-not (Test-Path "HKCU:\Software\Classes\$scheme")) "protocol removed"
$s = Get-Content (Join-Path $tmp 'settings.json') -Raw | ConvertFrom-Json
Assert-Equal $s.theme 'dark' "unrelated setting preserved"
Assert-True (-not $s.PSObject.Properties['hooks']) "our hooks fully removed"
Remove-Item $tmp -Recurse -Force
Write-Host "uninstall.tests PASSED"
```

- [ ] **Step 3: Run test to verify it passes**

Run: `powershell -ExecutionPolicy Bypass -File tests/uninstall.tests.ps1`
Expected: PASS — prints `uninstall.tests PASSED`.

- [ ] **Step 4: Commit**

```bash
git add uninstall.ps1 tests/uninstall.tests.ps1
git commit -m "feat: uninstaller removes v2 files, registry keys, and hooks"
```

---

### Task 8: Docs + run the full test suite

**Files:**
- Modify: `README.md`
- Create: `tests/run-all.ps1`

- [ ] **Step 1: Add a suite runner**

Create `tests/run-all.ps1`:

```powershell
$ErrorActionPreference = 'Stop'
$fail = 0
Get-ChildItem "$PSScriptRoot\*.tests.ps1" | ForEach-Object {
    Write-Host "== $($_.Name) =="
    try { & powershell -NoProfile -ExecutionPolicy Bypass -File $_.FullName; if ($LASTEXITCODE) { $fail++ } }
    catch { Write-Host $_; $fail++ }
}
if ($fail) { Write-Host "FAILED: $fail suite(s)"; exit 1 } else { Write-Host "ALL SUITES PASSED" }
```

- [ ] **Step 2: Run the full suite**

Run: `powershell -ExecutionPolicy Bypass -File tests/run-all.ps1`
Expected: prints `ALL SUITES PASSED`.

- [ ] **Step 3: Update README**

In `README.md`, update the feature list and add a "How it works (v2)" section describing: the `cctoast://` protocol, clicking the toast to focus the VS Code window (window-level only), the custom AUMID for the "Claude Code" header, and that the input/selection feature is intentionally not included. Note `icon.png` can be regenerated with `tools/make-icon.ps1` and replaced.

- [ ] **Step 4: Commit**

```bash
git add README.md tests/run-all.ps1
git commit -m "docs: document v2 click-to-VS-Code flow; add test suite runner"
```

---

## Self-Review

**Spec coverage:**
- §1 modern UI → Task 4 (ToastGeneric, icon, attribution). ✓
- §1 click→VS Code → Tasks 4 (launch URI) + 5 (handler). ✓
- §2 protocol activation choice → Tasks 4/5/6. ✓
- §3.1 hook script ASCII + UTF-8 labels → preserved (Global Constraints; Task 4 keeps upper half). ✓
- §3.2 handler `code -r` + SetForegroundWindow → Task 5. ✓
- §3.3 installer copy + AUMID + protocol + hook merge → Task 6. ✓
- §3.4 uninstaller registry + files + hooks → Task 7. ✓
- §3.5 icon → Task 3. ✓
- §5 error handling (code missing, cwd missing, idempotent upgrade) → Task 5 (exit 0 guards), Task 2 (idempotent merge tests). ✓
- §6 testing against temp dir + throwaway names → Tasks 6/7 use `-ClaudeDir`, `-AppId`, `-Scheme`. ✓

**Placeholder scan:** No TBD/TODO; every code step shows full code. ✓

**Type consistency:** `New-ToastLaunchUri` / `ConvertFrom-ToastLaunchUri` / `Set-ToastHook` / `Remove-ToastHook` names match across Tasks 1,2,4,5,6,7. AUMID `Claude.Code.ToastNotify` and scheme `cctoast` consistent across Tasks 4,6,7 (tests use `.Test` / `cctoasttest` throwaways). ✓

**Note for executor:** Task 4 Step 3 renders a real toast and writes a real (non-test) HKCU AUMID key for the visual check; this is the production AUMID and is fine to leave (Task 6 re-creates it). Tests in Tasks 6/7 use throwaway `.Test`/`cctoasttest` names and clean themselves up.
