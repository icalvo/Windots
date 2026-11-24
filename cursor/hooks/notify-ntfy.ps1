$TopicUrl = 'https://ntfy.sh/ignacio-cursor-agent-49498181'

function Show-WindowsToast {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        [Parameter(Mandatory = $true)]
        [string]$Body
    )

    try {
        $null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
        $null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime]

        $titleXml = [System.Security.SecurityElement]::Escape($Title)
        $bodyXml = [System.Security.SecurityElement]::Escape($Body)

        $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
        $xml.LoadXml(@"
<toast>
  <visual>
    <binding template="ToastGeneric">
      <text>$titleXml</text>
      <text>$bodyXml</text>
    </binding>
  </visual>
</toast>
"@)

        # PowerShell's registered AppUserModelID so the toast is allowed to show.
        $appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
        $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)
    } catch {
        # Fail open if the toast cannot be shown either.
    }
}

function Get-ConversationTitle {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConversationId
    )

    $chatsRoot = Join-Path $env:USERPROFILE '.cursor\chats'
    if (-not (Test-Path -LiteralPath $chatsRoot)) { return $null }

    $meta = Get-ChildItem -LiteralPath $chatsRoot -Directory -ErrorAction SilentlyContinue |
        ForEach-Object {
            $candidate = Join-Path $_.FullName (Join-Path $ConversationId 'meta.json')
            if (Test-Path -LiteralPath $candidate) { $candidate }
        } |
        Select-Object -First 1

    if (-not $meta) { return $null }

    try {
        $title = (Get-Content -LiteralPath $meta -Raw -ErrorAction Stop | ConvertFrom-Json).title
        if ($title -is [string] -and $title.Trim()) { return $title.Trim() }
    } catch {
        return $null
    }

    return $null
}

$stdin = [Console]::OpenStandardInput()
$raw = [System.IO.StreamReader]::new($stdin, [System.Text.Encoding]::UTF8).ReadToEnd()
if (-not $raw) { exit 0 }

try {
    $data = $raw | ConvertFrom-Json
} catch {
    exit 0
}

if ($data.status -ne 'completed') { exit 0 }

$parts = @('Status: completed')
if ($data.model) { $parts += "Model: $($data.model)" }
if ($data.conversation_id) {
    $id = $data.conversation_id
    $short = if ($id.Length -gt 8) { $id.Substring(0, 8) + '...' } else { $id }
    $parts += "Conversation: $short"
}
if ($data.workspace_roots -and $data.workspace_roots.Count -gt 0) {
    $parts += "Workspace: $(Split-Path $data.workspace_roots[0] -Leaf)"
}

$title = $null
foreach ($candidate in @($data.conversation_title, $data.title, $data.session_name, $data.name)) {
    if ($candidate -is [string] -and $candidate.Trim()) {
        $title = $candidate.Trim()
        break
    }
}
if (-not $title -and $data.conversation_id) {
    $title = Get-ConversationTitle -ConversationId $data.conversation_id
}
if (-not $title) { $title = 'Cursor: agent completed' }

$headers = @{
    Title    = $title
    Priority = '3'
    Tags     = 'white_check_mark'
}

try {
    Invoke-RestMethod -Method POST -Uri $TopicUrl -Body ($parts -join "`n") -Headers $headers -ErrorAction Stop | Out-Null
} catch {
    Show-WindowsToast -Title 'Cursor: ntfy failed' -Body $_.Exception.Message
}

exit 0
