# Toast v2 — Click-to-VS-Code + Modern UI (Design)

- Date: 2026-06-17
- Repo: `claude-code-toast-notify`
- Status: Approved design, pending implementation plan

## 1. Goal

Upgrade the Windows toast notifier so that:

1. **Modern UI** — replace the legacy `ToastText02` template with a
   `ToastGeneric` toast: app logo, title, body, and an attribution line
   (`<workspace> @ <branch>`). Minimal layout, **no buttons**; the whole toast
   is clickable.
2. **Click → return to VS Code (top priority)** — clicking the toast brings the
   VS Code **window** for that workspace to the foreground.

Out of scope this version:

- **Input box / selection that answers Claude** — dropped. Feeding text back
  into the running Claude Code CLI requires COM activation plus keystroke
  injection into the terminal; unreliable. Not built.
- **Terminal-tab-level focus** — VS Code exposes no external API to focus a
  specific integrated-terminal tab. We focus the window only.

## 2. Approach decision

Toast activation can be delivered two ways:

- **COM activation** — required to receive `<input>` values and button results,
  but needs a registered COM activator CLSID on a Start Menu shortcut. Heavy and
  fragile for a script-based tool.
- **Protocol activation** (chosen) — `activationType="protocol"` launches a
  registered custom URI when the toast is clicked. No COM, no packaging, HKCU
  registry only (no admin). Sufficient because we only need to *trigger an
  action* (open VS Code), not *receive typed input*.

## 3. Components

### 3.1 `claude-hook-toast.ps1` (modified)
- Reads hook JSON from stdin as UTF-8 (unchanged).
- Computes `workspace` (leaf of `cwd`) and `branch`
  (`git -C <cwd> rev-parse --abbrev-ref HEAD`) (unchanged).
- Body text by event (unchanged): Stop → last assistant message; Notification →
  `message`; SessionStart/SessionEnd → localized labels from `messages.json`.
- **New:** emit a `ToastGeneric` XML payload instead of `ToastText02`:
  - `<image placement="appLogoOverride" hint-crop="circle" src="<icon path>">`
  - `<text>` 1 = title `Claude Code`
  - `<text>` 2 = body (the summary/message, truncated to `$max`)
  - `<text placement="attribution">` = `<workspace> @ <branch>`
  - root `<toast launch="cctoast://open?path=<urlencoded cwd>"
    activationType="protocol">`
- Shown via the custom AUMID `Claude.Code.ToastNotify` so the toast header reads
  "Claude Code" with the bundled icon (replaces the raw GUID line).
- Source stays **ASCII-only** (Windows PowerShell 5.1 reads BOM-less `.ps1` in
  the system ANSI code page, e.g. CP949). All human text comes from
  `messages.json` / stdin, read as UTF-8.

### 3.2 `cctoast-open.ps1` (new) — protocol handler
- Invoked by Windows as `cctoast-open.ps1 "cctoast://open?path=<urlencoded>"`.
- Parses the URI, URL-decodes `path` → `cwd`.
- Runs `code --reuse-window "<cwd>"` to focus/open that workspace window.
- Then best-effort Win32 `SetForegroundWindow` on a window whose title contains
  the workspace leaf name and "Visual Studio Code", to guarantee it comes to
  front.
- All failures are swallowed (logged only); never throws a visible error.

### 3.3 `install.ps1` (modified)
- Copies `claude-hook-toast.ps1`, `cctoast-open.ps1`, `messages.json`, and the
  icon into `~/.claude/` (configurable `-ClaudeDir` for testing).
- Registers, in **HKCU only**:
  - Custom AUMID: `HKCU\Software\Classes\AppUserModelId\Claude.Code.ToastNotify`
    with `DisplayName = "Claude Code"` and `IconUri = <icon path>`.
  - Custom protocol: `HKCU\Software\Classes\cctoast` (`URL Protocol`) with
    `shell\open\command =
    powershell -ExecutionPolicy Bypass -File "<cctoast-open.ps1>" "%1"`.
- Merges `Notification` + `Stop` hooks into `settings.json` with an
  install-time absolute, forward-slash path (works from git bash / PowerShell /
  cmd). Idempotent: existing hooks referencing `claude-hook-toast.ps1` are
  replaced, not duplicated. Backs up `settings.json` → `.bak`.

### 3.4 `uninstall.ps1` (modified)
- Removes the toast hooks from `settings.json` (existing behavior).
- Deletes the installed scripts, icon, and `messages.json`.
- Removes the HKCU registry keys for the AUMID and the `cctoast` protocol.

### 3.5 Icon
- A simple icon generated with `System.Drawing` (rounded square + "C"), bundled
  as `icon.png`. README notes how to replace it.

## 4. Data flow

```
Claude (Stop / Notification)
   └─ stdin JSON {hook_event_name, cwd, transcript_path}
        └─ claude-hook-toast.ps1
             builds ToastGeneric (launch = cctoast://open?path=<cwd>)
             shows toast via AUMID Claude.Code.ToastNotify
user clicks toast
   └─ Windows launches cctoast://open?path=<cwd>
        └─ HKCU\...\cctoast\shell\open\command
             └─ cctoast-open.ps1 "<uri>"
                  decode cwd → code --reuse-window <cwd> → SetForegroundWindow
                       └─ VS Code window for that workspace comes to front
```

## 5. Error handling

| Case | Behavior |
|------|----------|
| `code` not on PATH | handler logs and exits 0; toast display unaffected |
| `cwd` missing / not a dir | click is a no-op; no crash |
| not a git repo | branch omitted; header shows workspace only |
| upgrade from v1 | install removes old `claude-hook-toast.ps1` hook entries, re-adds |
| non-ASCII in labels | lives in `messages.json` (UTF-8), never in `.ps1` source |
| registry write fails | install reports the failure; files still copied |

## 6. Testing

All tests run against a temporary fake `~/.claude` (via `-ClaudeDir`) and a
throwaway registry-key prefix where possible, so the live environment is never
disturbed.

1. **Install** into temp dir → assert files copied, `settings.json` merged
   (existing settings preserved), AUMID + `cctoast` registry keys present.
2. **Idempotency** → run install twice → exactly one toast hook per event.
3. **Toast render** → pipe a sample Stop payload → toast appears with title,
   body, attribution, icon (manual visual check).
4. **Protocol** → invoke `cctoast://open?path=<real repo>` → assert
   `code --reuse-window` is called and the VS Code window comes to front.
5. **Uninstall** → assert hooks removed, files deleted, registry keys removed,
   unrelated settings preserved.

## 7. Known limitations

- Window-level focus only; no terminal-tab focus (VS Code limitation).
- If multiple VS Code windows have the same workspace folder open, focus is
  ambiguous; first match wins.
- Requires the VS Code `code` CLI on PATH.
