# Claude Code Toast Notify (Windows)

Windows toast notifications for [Claude Code](https://claude.com/claude-code) hook
events. Zero dependencies — uses only built-in Windows + PowerShell.

- **Header**: `Claude Code | <workspace> @ <branch>`
- **Body**:
  - `Stop` event → a snippet of Claude's last response
  - `Notification` event → Claude's message (waiting for input / permission)
- **Click the toast** to focus the VS Code window for that workspace
- Modern **ToastGeneric** card with the "Claude Code" header (custom AUMID `Claude.Code.ToastNotify`) and icon (`icon.png`)
- Works whether your hook shell is **git bash, PowerShell, or cmd**.
- Labels available in **English / 日本語 / 한국어**.

> Derived from [soulee-dev/claude-code-notify-powershell](https://github.com/soulee-dev/claude-code-notify-powershell).
> Adds: workspace + branch in the header, last-response body, cross-shell install, i18n, click-to-focus VS Code, custom AUMID.

---

## How it works (v2)

1. **On Stop/Notification**, the hook builds a `cctoast://open?path=<percent-encoded cwd>` URI and shows a ToastGeneric toast with that URI as the click target. The toast header reads "Claude Code" (via the custom AUMID).

2. **The installer** (HKCU only, no elevation required) registers:
   - A custom AUMID `Claude.Code.ToastNotify` with `DisplayName = "Claude Code"` and the project `icon.png`, so Windows displays the friendly name and icon in the toast header.
   - The `cctoast:` custom URI scheme pointing to `cctoast-open.ps1` in `~/.claude/`.

3. **Clicking the toast** runs `cctoast-open.ps1`, which calls `code --reuse-window "<cwd>"` and uses `SetForegroundWindow` to bring the matching VS Code window to the foreground.

   > **Known limitation**: this focuses the VS Code *window*, not a specific integrated-terminal tab. VS Code exposes no public API for selecting a particular terminal instance.

   > **Not implemented**: responding to Claude from an input box in the toast. That would require COM activation of the app and unreliable keystroke injection — deliberately left out.

---

## Install

From this folder, in PowerShell:

```powershell
# English (default)
.\install.ps1

# 日本語
.\install.ps1 -Lang ja

# 한국어
.\install.ps1 -Lang ko
```

The installer accepts these parameters:

| Parameter    | Default                        | Description                              |
|--------------|--------------------------------|------------------------------------------|
| `-Lang`      | `en`                           | Label language (`en` / `ja` / `ko`)      |
| `-ClaudeDir` | `~/.claude`                    | Destination for installed scripts        |
| `-AppId`     | `Claude.Code.ToastNotify`      | AUMID registered in HKCU                 |
| `-Scheme`    | `cctoast`                      | Custom URI scheme registered in HKCU     |

The installer:
1. Copies `claude-hook-toast.ps1`, `cctoast-open.ps1`, `messages.json`, `icon.png`, and `lib\cctoast-lib.ps1` into `~/.claude/`.
2. Registers the custom AUMID (`Claude.Code.ToastNotify`, DisplayName "Claude Code") and `cctoast:` protocol in HKCU — **no elevation required**.
3. Merges `Notification` and `Stop` hooks into `~/.claude/settings.json` using an **absolute path resolved at install time** (no `%USERPROFILE%` / `$env:` expansion, so hooks run from any shell).
4. Backs up `settings.json` to `settings.json.bak` and is **idempotent** (re-running upgrades in place, never duplicates).

> **Requirement**: the `code` CLI must be on `PATH` for the click-to-focus action to work. On most VS Code installs, run `Shell Command: Install 'code' command in PATH` from the Command Palette once.

Then open `/hooks` in Claude Code once (or restart) to load the hooks.

## Uninstall

```powershell
.\uninstall.ps1
```

Accepts the same `-ClaudeDir`, `-AppId`, and `-Scheme` parameters as the installer.

Removes the toast hooks from `settings.json`, deletes the installed files (`claude-hook-toast.ps1`, `cctoast-open.ps1`, `messages.json`, `icon.png`, `lib\cctoast-lib.ps1`), and removes the AUMID and `cctoast:` protocol registry keys from HKCU. Other settings are preserved.

## Customize

- **Body length**: change `$max` in `claude-hook-toast.ps1`.
- **Labels**: edit `messages.json` (UTF-8). Add a new top-level language key and pass it via `-Lang`.
- **Events**: by default `Notification` (input/permission prompt) and `Stop` (response finished). Edit the hooks in `settings.json` to add/remove events such as `SessionStart` / `SessionEnd`.

## Notes / gotchas

- **Keep `claude-hook-toast.ps1` and `cctoast-open.ps1` ASCII-only.** Windows PowerShell 5.1 reads a BOM-less `.ps1` in the system ANSI code page (e.g. CP949 on Korean Windows), which corrupts non-ASCII literals. All human-language text lives in `messages.json` / the hook payload and is read explicitly as UTF-8, so it is safe regardless of the script's own encoding.
- The AUMID and `cctoast:` protocol are registered in **HKCU only** — no admin rights needed, and uninstall fully cleans them up.
- The `icon.png` shipped in this repo is used as the toast icon. Replace it with your own 256×256 PNG if desired; re-run `install.ps1` to update the installed copy.

## License

MIT — see [LICENSE](LICENSE).
