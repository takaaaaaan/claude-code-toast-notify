# Task 7 Report: Rewrite uninstall.ps1 + Integration Test

## Test Output

```
Installed toast hook v2 (lang=en).
  scripts  : C:\Users\taka2\AppData\Local\Temp\cctoast-uninstall-a6f10b34943f4c9fa7bea178489a467a
  AUMID    : Claude.Code.ToastNotify.Test
  protocol : cctoasttest://
Open /hooks in Claude Code once, or restart, to load the new hooks.
Uninstalled toast hook v2 from C:\Users\taka2\AppData\Local\Temp\cctoast-uninstall-a6f10b34943f4c9fa7bea178489a467a.
  ok: hook script removed
  ok: handler removed
  ok: AUMID removed
  ok: protocol removed
  ok: unrelated setting preserved
  ok: our hooks fully removed
uninstall.tests PASSED
```

## Registry Leak Check

```
Test-Path 'HKCU:\Software\Classes\AppUserModelId\Claude.Code.ToastNotify.Test' => False
Test-Path 'HKCU:\Software\Classes\cctoasttest'                                 => False
```

Both registry keys confirmed absent after test cleanup.

## Commit

Commit: e1abe86  
Branch: feat/toast-v2  
Files: uninstall.ps1 (rewritten), tests/uninstall.tests.ps1 (new)

## Summary

- `uninstall.ps1` rewritten to: dot-source `lib\cctoast-lib.ps1`, call `Remove-ToastHook` for Notification and Stop events, delete all v2 installed files (claude-hook-toast.ps1, cctoast-open.ps1, messages.json, icon.png, lib\cctoast-lib.ps1), remove the empty `lib\` directory, and delete HKCU AUMID + protocol registry keys. Accepts `$AppId` and `$Scheme` parameters with production defaults.
- `tests/uninstall.tests.ps1` performs a full install-then-uninstall cycle using throwaway names (`Claude.Code.ToastNotify.Test` / `cctoasttest`) in a temp directory. All 6 assertions pass. The `finally` block cleans up regardless of failure.
