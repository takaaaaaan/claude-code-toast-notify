# Task 1 Report: cctoast Protocol URI Helpers

## Summary
Successfully implemented cctoast protocol URI helpers library with full test coverage following strict TDD methodology.

## Implementation Details

### Test-Driven Development Process
1. **Created tests/assert.ps1** - Helper assertion functions for test framework
2. **Created tests/uri.tests.ps1** - Tests written FIRST (confirmed FAIL before implementation)
3. **Created lib/cctoast-lib.ps1** - Pure PowerShell implementation
4. **Verified PASS** - All tests passing after implementation

### Test Results
All 4 assertions passed:
- ✓ uri has scheme/prefix (cctoast://open?path=...)
- ✓ uri is percent-encoded (no raw backslash/space)
- ✓ roundtrip restores cwd exactly (encode/decode cycle)
- ✓ missing path parameter returns null

### Files Created
- `tests/assert.ps1` - Reusable test assertion helpers
- `tests/uri.tests.ps1` - URI encoding/decoding test suite
- `lib/cctoast-lib.ps1` - Implementation with two functions:
  - `New-ToastLaunchUri` - Encodes working directory into cctoast:// URI
  - `ConvertFrom-ToastLaunchUri` - Decodes cctoast:// URI back to path

### Technical Compliance
- Source is ASCII-only (CP949 safety for Windows PowerShell 5.1)
- Uses pure PowerShell with no external dependencies
- Uses [System.Uri]::EscapeDataString/UnescapeDataString for RFC 3986 compliance
- Test execution: `powershell -ExecutionPolicy Bypass -File tests\uri.tests.ps1`

## Commit
- **Hash**: 89da04a
- **Message**: "feat: add cctoast protocol uri helpers with tests"
- **Author**: Ueno Gohong <taka20030902@gmail.com>

## Status
✓ All tests passing
✓ Code committed
✓ No concerns

## Follow-up: Test Assertion Fix
**Commit**: 4cc35b7
**Change**: Replaced `-like` wildcard assertion with regex `-match` on line 7 of tests/uri.tests.ps1 to require literal `?` character in URI.
- Before: `Assert-True ($uri -like 'cctoast://open?path=*')`
- After: `Assert-True ($uri -match '^cctoast://open\?path=')`
**Test Result**: `uri.tests PASSED` (all 4 assertions pass)
