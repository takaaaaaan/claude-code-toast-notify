# Task 5 Report: cctoast Protocol Handler

## Status
PASS

## Commit
945564d — feat: cctoast protocol handler focuses VS Code workspace window

## $target adjustment
No change was needed. The original target path `C:\Users\taka2\Desktop\final-project\metabolic-twin-fe` exists on this machine (`Test-Path` returned `True`), so the test was used verbatim as specified.

## TDD Evidence

### Step 1 — Test written first, confirmed FAIL
Ran `powershell -ExecutionPolicy Bypass -File tests/handler.tests.ps1` before creating `cctoast-open.ps1`.

Output:
```
The argument '...\cctoast-open.ps1' to the -File parameter does not exist.
ASSERT FAILED: fake code was invoked
```

Failure reason: `cctoast-open.ps1` did not exist yet, so the handler subprocess could not run and the fake `code.cmd` was never invoked.

### Step 2 — Implementation created
`cctoast-open.ps1` created verbatim per spec:
- Sources `lib\cctoast-lib.ps1` via `$PSScriptRoot`
- Calls `ConvertFrom-ToastLaunchUri` to decode the URI
- Guards with `Test-Path -LiteralPath $cwd` before proceeding
- Calls `code --reuse-window "$cwd"`
- Best-effort foreground focus via `SetForegroundWindow` P/Invoke
- `$ErrorActionPreference = 'SilentlyContinue'` + final `exit 0` — never throws visibly
- Verified ASCII-only (no bytes > 127)

### Step 3 — Test confirmed PASS
```
  ok: fake code was invoked
  ok: code called with --reuse-window
  ok: code called with the target path
handler.tests PASSED
```

## Files Modified
- `cctoast-open.ps1` (created)
- `tests/handler.tests.ps1` (created)

## Concerns
None. The `Start-Sleep -Milliseconds 400` in the foreground-focus block means the handler has a brief pause before checking for a VS Code process window; this is harmless in production (fires after `code` is launched) and is not exercised by the test (which only checks that `code --reuse-window <path>` was called).

## Fix Note (post-review, commit a8f6046)

**What changed:** `tests/handler.tests.ps1` previously hardcoded the machine-specific path `C:\Users\taka2\Desktop\final-project\metabolic-twin-fe` as the test target. Because `cctoast-open.ps1` guards on `Test-Path`, the test would fail on any machine where that path does not exist — for the wrong reason (path missing, not handler logic). The fix creates `$target = Join-Path $work 'demo-workspace'` under the temp work area and calls `New-Item -ItemType Directory` to ensure it always exists. The path assertion was updated from `'metabolic-twin-fe'` to `'demo-workspace'` to match. No other files were changed.

**Test command and output:**
```
powershell -ExecutionPolicy Bypass -File tests/handler.tests.ps1

  ok: fake code was invoked
  ok: code called with --reuse-window
  ok: code called with the target path
handler.tests PASSED
```
