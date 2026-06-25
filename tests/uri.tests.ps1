$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\assert.ps1"
. "$PSScriptRoot\..\lib\cctoast-lib.ps1"

$cwd = 'C:\Users\taka2\Desktop\final-project\metabolic-twin-fe'
$uri = New-ToastLaunchUri $cwd
Assert-True ($uri -match '^cctoast://open\?path=') "uri has scheme/prefix"
Assert-True ($uri -notmatch '[\\ ]') "uri is percent-encoded (no raw backslash/space)"
Assert-Equal (ConvertFrom-ToastLaunchUri $uri) $cwd "roundtrip restores cwd exactly"
Assert-Equal (ConvertFrom-ToastLaunchUri 'cctoast://open') $null "missing path -> null"
$u2 = New-ToastLaunchUri $cwd 'myscheme'
Assert-True ($u2 -match '^myscheme://open\?path=') "custom scheme honored"
Assert-Equal (ConvertFrom-ToastLaunchUri $u2) $cwd "custom-scheme roundtrip restores cwd"

# pids carry the ancestor process chain for the VS Code extension
Assert-Equal (Get-ToastLaunchPids $uri) $null "no pids -> null"
$u3 = New-ToastLaunchUri $cwd 'cctoast' '111,222,333'
Assert-True ($u3 -match 'path=') "pids uri still has path"
Assert-True ($u3 -match 'pids=') "pids uri has pids param"
Assert-Equal (ConvertFrom-ToastLaunchUri $u3) $cwd "cwd still recoverable with pids present"
Assert-Equal (Get-ToastLaunchPids $u3) '111,222,333' "pids roundtrip"
Write-Host "uri.tests PASSED"
