$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\assert.ps1"
. "$PSScriptRoot\..\lib\cctoast-lib.ps1"

# starts with an unrelated hook that must be preserved
$json = '{ "hooks": { "Stop": [ { "hooks": [ { "type":"command","command":"echo other" } ] } ] } }'
$s = $json | ConvertFrom-Json

Set-ToastHook $s 'Stop' 'powershell -File "C:/x/claude-hook-toast.ps1" ja'
Set-ToastHook $s 'Stop' 'powershell -File "C:/x/claude-hook-toast.ps1" ko'  # re-run -> replace
Set-ToastHook $s 'Notification' 'powershell -File "C:/x/claude-hook-toast.ps1" ko'

$stop = @($s.hooks.Stop)
Assert-Equal $stop.Count 2 "Stop keeps unrelated hook + exactly one of ours"
$ours = @($stop | Where-Object { $_.hooks[0].command -match 'claude-hook-toast' })
Assert-Equal $ours.Count 1 "exactly one of our Stop hooks (idempotent)"
Assert-True ($ours[0].hooks[0].command -match ' ko$') "latest command wins (ko)"

Remove-ToastHook $s 'Stop'
Remove-ToastHook $s 'Notification'
$stop2 = @($s.hooks.Stop)
Assert-Equal $stop2.Count 1 "Stop retains only the unrelated hook after removal"
Assert-True (-not $s.hooks.PSObject.Properties['Notification']) "empty Notification event removed"
Write-Host "hooks.tests PASSED"
