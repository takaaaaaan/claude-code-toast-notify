param(
    [string]$Lang = 'en'
)

# Claude Code Notification Hook (Windows toast) -- portable version.
#
# Shows a Windows toast when Claude Code fires Notification / Stop events.
#   - Header : "Claude Code | <workspace> @ <branch>"
#   - Body   : last assistant message (Stop) or the event message (Notification)
#
# Localized fixed labels (en / ja / ko) are loaded at runtime from
# messages.json placed next to this script, read as UTF-8.
#
# IMPORTANT: keep THIS script source ASCII-only. Windows PowerShell 5.1 reads
# a BOM-less .ps1 in the system ANSI code page (e.g. CP949), which corrupts any
# non-ASCII literal. All human-language text lives in messages.json / stdin and
# is read explicitly as UTF-8, so it is unaffected by the .ps1 encoding.
#
# Invoked identically from git bash, PowerShell, or cmd:
#   powershell -ExecutionPolicy Bypass -File "<...>/claude-hook-toast.ps1" <lang>

$ErrorActionPreference = 'Stop'

# --- read hook payload from stdin as UTF-8 ---------------------------------
$reader = New-Object System.IO.StreamReader([Console]::OpenStandardInput(), [System.Text.Encoding]::UTF8)
$raw = $reader.ReadToEnd()
$json = $raw | ConvertFrom-Json -ErrorAction SilentlyContinue
$hookEvent = $json.hook_event_name
$cwd = $json.cwd

# --- load localized labels (UTF-8) -----------------------------------------
$L = $null
try {
    $msgPath = Join-Path $PSScriptRoot 'messages.json'
    if (Test-Path -LiteralPath $msgPath) {
        $msgReader = New-Object System.IO.StreamReader($msgPath, [System.Text.Encoding]::UTF8)
        $allMsgs = $msgReader.ReadToEnd() | ConvertFrom-Json
        $msgReader.Close()
        if ($allMsgs.PSObject.Properties[$Lang]) { $L = $allMsgs.$Lang }
        elseif ($allMsgs.PSObject.Properties['en']) { $L = $allMsgs.en }
    }
} catch { $L = $null }

function Msg($key, $fallback) {
    if ($L -and $L.PSObject.Properties[$key] -and $L.$key) { return [string]$L.$key }
    return $fallback
}

# --- last assistant message from a transcript .jsonl -----------------------
function Get-LastAssistantText {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) { return $null }
    $lines = Get-Content -LiteralPath $Path -Encoding UTF8
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        $line = $lines[$i].Trim()
        if (-not $line) { continue }
        try { $obj = $line | ConvertFrom-Json } catch { continue }
        if ($obj.type -ne 'assistant') { continue }
        $content = $obj.message.content
        if (-not $content) { continue }
        $texts = @()
        foreach ($block in $content) {
            if ($block.type -eq 'text' -and $block.text) { $texts += $block.text }
        }
        if ($texts.Count -gt 0) { return ($texts -join "`n") }
    }
    return $null
}

# --- workspace + git branch from cwd ---------------------------------------
$workspace = ""
$branch = ""
if (-not [string]::IsNullOrWhiteSpace($cwd)) {
    try { $workspace = Split-Path -Leaf $cwd } catch { $workspace = "" }
    try {
        $b = & git -C "$cwd" rev-parse --abbrev-ref HEAD 2>$null
        if ($LASTEXITCODE -eq 0 -and $b) { $branch = ([string]$b).Trim() }
    } catch { $branch = "" }
}

$header = 'Claude Code'
if ($workspace) {
    $context = $workspace
    if ($branch) { $context = "$workspace @ $branch" }
    $header = "Claude Code | $context"
}

# --- body message by event -------------------------------------------------
$message = switch ($hookEvent) {
    'SessionStart' { Msg 'session_start' 'Session started' }
    'SessionEnd'   { Msg 'session_completed' 'Session completed' }
    'Stop' {
        $t = Get-LastAssistantText $json.transcript_path
        if ($t) { $t } else { Msg 'response_finished' 'Response finished' }
    }
    'Notification' { $json.message }
    default        { "$hookEvent : $($json.message)" }
}

# collapse whitespace + truncate so the body stays compact
$max = 250
$message = ($message -replace '\s+', ' ').Trim()
if ([string]::IsNullOrEmpty($message)) { $message = Msg 'response_finished' 'Response finished' }
if ($message.Length -gt $max) { $message = $message.Substring(0, $max).TrimEnd() + ' ...' }

# --- show Windows toast ----------------------------------------------------
$template = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]::GetTemplateContent(
    [Windows.UI.Notifications.ToastTemplateType, Windows.UI.Notifications, ContentType = WindowsRuntime]::ToastText02
)
$template.SelectSingleNode('//text[@id="1"]').InnerText = $header
$template.SelectSingleNode('//text[@id="2"]').InnerText = $message
$appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($template)
