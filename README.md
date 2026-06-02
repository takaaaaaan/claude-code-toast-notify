# Claude Code Toast Notify (Windows)

Windows toast notifications for [Claude Code](https://claude.com/claude-code) hook
events. Zero dependencies — uses only built-in Windows + PowerShell.

- **Header**: `Claude Code | <workspace> @ <branch>`
- **Body**:
  - `Stop` event → a snippet of Claude's last response
  - `Notification` event → Claude's message (waiting for input / permission)
- Works whether your hook shell is **git bash, PowerShell, or cmd**.
- Labels available in **English / 日本語 / 한국어**.

> Derived from [soulee-dev/claude-code-notify-powershell](https://github.com/soulee-dev/claude-code-notify-powershell).
> Adds: workspace + branch in the header, last-response body, cross-shell install, i18n.

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

The installer:
1. copies `claude-hook-toast.ps1` + `messages.json` into `~/.claude/`,
2. merges `Notification` and `Stop` hooks into `~/.claude/settings.json`
   using an **absolute path resolved at install time** (no `%USERPROFILE%` /
   `$env:` expansion, so it runs from any shell),
3. backs up `settings.json` to `settings.json.bak` and is **idempotent**
   (re-running upgrades in place, never duplicates).

Then open `/hooks` in Claude Code once (or restart) to load the hooks.

## Uninstall

```powershell
.\uninstall.ps1
```

Removes the toast hooks from `settings.json` and deletes the installed files.
Other settings are preserved.

## Customize

- **Body length**: change `$max` in `claude-hook-toast.ps1`.
- **Labels**: edit `messages.json` (UTF-8). Add a new top-level language key and
  pass it via `-Lang`.
- **Events**: by default `Notification` (input/permission prompt) and `Stop`
  (response finished). Edit the hooks in `settings.json` to add/remove events
  such as `SessionStart` / `SessionEnd`.

## Notes / gotchas

- **Keep `claude-hook-toast.ps1` ASCII-only.** Windows PowerShell 5.1 reads a
  BOM-less `.ps1` in the system ANSI code page (e.g. CP949 on Korean Windows),
  which corrupts non-ASCII literals. All human-language text lives in
  `messages.json` / the hook payload and is read explicitly as UTF-8, so it is
  safe regardless of the script's own encoding.
- The tiny `{1AC14E77-...}` line at the top of the toast is the app identity
  (AUMID) of PowerShell. To show a friendlier name you can register a custom
  AUMID with a `DisplayName` in the registry — optional, not required.

## License

MIT — see [LICENSE](LICENSE).
