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
Write-Host "uri.tests PASSED"
