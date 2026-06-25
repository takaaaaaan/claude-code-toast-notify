# Task 6 Report — Installer v2 (AUMID + cctoast protocol)

## Status
PASS

## Commit
`a35ae2a` — feat: installer registers AUMID + cctoast protocol and copies v2 files

## Test Output
```
Installed toast hook v2 (lang=ja).
  scripts  : C:\Users\taka2\AppData\Local\Temp\cctoast-install-0170a1f63ea24a6d92ac1c0ecd272cea
  AUMID    : Claude.Code.ToastNotify.Test
  protocol : cctoasttest://
Open /hooks in Claude Code once, or restart, to load the new hooks.
Installed toast hook v2 (lang=ko).
  scripts  : C:\Users\taka2\AppData\Local\Temp\cctoast-install-0170a1f63ea24a6d92ac1c0ecd272cea
  AUMID    : Claude.Code.ToastNotify.Test
  protocol : cctoasttest://
Open /hooks in Claude Code once, or restart, to load the new hooks.
  ok: hook script copied
  ok: handler copied
  ok: lib copied
  ok: icon copied
  ok: AUMID registered
  ok: protocol registered
  ok: unrelated setting preserved
  ok: exactly one of our Stop hooks (idempotent across re-run)
  ok: latest lang wins
install.tests PASSED
```

## Test Summary
9/9 assertions passed — files copied, AUMID and protocol keys created in HKCU, unrelated settings preserved, idempotency confirmed, lang override works.

## Concerns
None. Registry writes are HKCU-only. Test cleans up its own throwaway AppId/Scheme keys and temp directory. Line-ending warnings (LF -> CRLF) from git are cosmetic only and do not affect runtime behavior.

---

## Fix Note — commit `8651bf7`

### Changes applied to `tests/install.tests.ps1`

1. **try/finally guard**: assertions moved into `try { ... }`, cleanup (`Remove-Item` of the two HKCU keys and `$tmp`) moved to `finally { ... }` with `-ErrorAction SilentlyContinue`. `Write-Host "install.tests PASSED"` kept inside `try` so it only prints on success.
2. **Notification hook assertion**: added check that the Notification hook entry referencing `claude-hook-toast` is present and deduplicated (count == 1).
3. **Forward-slash path assertion**: added check that the Stop hook command path uses forward slashes (`/claude-hook-toast.ps1`).
4. **Backup file assertion**: added check that `settings.json.bak` exists in the temp dir after install.

### Test output (12/12 assertions)
```
  ok: hook script copied
  ok: handler copied
  ok: lib copied
  ok: icon copied
  ok: AUMID registered
  ok: protocol registered
  ok: unrelated setting preserved
  ok: exactly one of our Stop hooks (idempotent across re-run)
  ok: latest lang wins
  ok: Notification hook merged
  ok: hook path uses forward slashes
  ok: settings.json backup created
install.tests PASSED
```

### HKCU key cleanup verification
```
Test-Path 'HKCU:\Software\Classes\AppUserModelId\Claude.Code.ToastNotify.Test' -> False
Test-Path 'HKCU:\Software\Classes\cctoasttest'                                 -> False
```
