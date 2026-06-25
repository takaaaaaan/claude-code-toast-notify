# Final Review Fix Note

## Issue

The installer's `-AppId` and `-Scheme` parameters were not plumbed into the hook command written to `settings.json`. Non-default values caused the toast to emit a `cctoast://` URI regardless of the registered scheme, and fire under the default AUMID instead of the custom one. Defaults worked; custom values were silently ignored.

## Edits Applied

### EDIT 1: `lib/cctoast-lib.ps1` — add optional `-Scheme` to `New-ToastLaunchUri`

Added `[string]$Scheme = 'cctoast'` parameter so callers can override the URI scheme. The return value now uses `${Scheme}://open?path=...` instead of the hardcoded `cctoast://` prefix.

### EDIT 2: `claude-hook-toast.ps1` — accept `-Scheme` and use it

- Added `[string]$Scheme = 'cctoast'` to the `param` block.
- Changed launch-URI construction from `New-ToastLaunchUri $cwd` / `'cctoast://open'` to `New-ToastLaunchUri $cwd $Scheme` / `"${Scheme}://open"`.

### EDIT 3: `install.ps1` — pass `-AppId` and `-Scheme` into the hook command

Changed the command-build line to append `-AppId "$AppId" -Scheme "$Scheme"` so the values provided to the installer are forwarded to the hook at runtime.

### EDIT 4: `tests/uri.tests.ps1` — custom-scheme roundtrip case

Added two assertions verifying that `New-ToastLaunchUri $cwd 'myscheme'` produces a URI starting with `myscheme://open?path=` and that `ConvertFrom-ToastLaunchUri` round-trips it back to the original path.

### EDIT 5: `tests/install.tests.ps1` — assert hook command carries AppId + Scheme

Added two assertions after the existing `$stop` block checking that the written hook command contains `-AppId "Claude.Code.ToastNotify.Test"` and `-Scheme "cctoasttest"`.

Incidental fix: the pre-existing `' ko$'` regex on the "latest lang wins" assertion was updated to `' ko '` because the lang token is now in the middle of the command string (followed by `-AppId` and `-Scheme`), not at the end.

## Full Suite Output

```
== handler.tests.ps1 ==
  ok: fake code was invoked
  ok: code called with --reuse-window
  ok: code called with the target path
handler.tests PASSED
== hooks.tests.ps1 ==
  ok: Stop keeps unrelated hook + exactly one of ours
  ok: exactly one of our Stop hooks (idempotent)
  ok: latest command wins (ko)
  ok: Stop retains only the unrelated hook after removal
  ok: empty Notification event removed
hooks.tests PASSED
== install.tests.ps1 ==
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
  ok: hook command passes custom AppId
  ok: hook command passes custom Scheme
install.tests PASSED
== uninstall.tests.ps1 ==
  ok: hook script removed
  ok: handler removed
  ok: AUMID removed
  ok: protocol removed
  ok: unrelated setting preserved
  ok: our hooks fully removed
uninstall.tests PASSED
== uri.tests.ps1 ==
  ok: uri has scheme/prefix
  ok: uri is percent-encoded (no raw backslash/space)
  ok: roundtrip restores cwd exactly
  ok: missing path -> null
  ok: custom scheme honored
  ok: custom-scheme roundtrip restores cwd
uri.tests PASSED
ALL SUITES PASSED
```

## Registry Leak Check

```
Test-Path 'HKCU:\Software\Classes\AppUserModelId\Claude.Code.ToastNotify.Test'  -> False
Test-Path 'HKCU:\Software\Classes\cctoasttest'                                  -> False
```

Both False — no registry leak.

## Commit

`84a9152` — fix: plumb -AppId and -Scheme through to the hook so custom values work
