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
