# Task 8 Report — Test Suite Runner + README v2

**STATUS**: DONE
**Commit**: 4fa41ae  (`docs: document v2 click-to-VS-Code flow; add test suite runner`)

## Suite runner output

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
uri.tests PASSED
ALL SUITES PASSED
```

## Files modified

- `tests/run-all.ps1` — created (exact content from spec)
- `README.md` — updated to reflect v2 features, added "How it works (v2)" section, updated Install/Uninstall/Notes sections

## Concerns

None. All 5 suites (handler, hooks, install, uninstall, uri) passed on the first run. The install/uninstall suites used throwaway HKCU keys (`Claude.Code.ToastNotify.Test` / `cctoasttest`) and cleaned up after themselves.
