$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\assert.ps1"
. "$PSScriptRoot\..\lib\cctoast-lib.ps1"

$cwd = 'C:\Users\taka2\Desktop\final-project\metabolic-twin-fe'
$uri = New-ToastLaunchUri $cwd
Assert-True ($uri -like 'cctoast://open?path=*') "uri has scheme/prefix"
Assert-True ($uri -notmatch '[\\ ]') "uri is percent-encoded (no raw backslash/space)"
Assert-Equal (ConvertFrom-ToastLaunchUri $uri) $cwd "roundtrip restores cwd exactly"
Assert-Equal (ConvertFrom-ToastLaunchUri 'cctoast://open') $null "missing path -> null"
Write-Host "uri.tests PASSED"
