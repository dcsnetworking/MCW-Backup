#Options
[CmdletBinding()]
param (
    
    #Mandatory parameters
    [Parameter(Mandatory)]
    [ValidateSet("Bedrock","Java")]
    [String]$MinecraftVersion,
    
    #Optional parameters
    [Parameter()]
    #The default output folder is this
    [System.IO.DirectoryInfo]$OutputFolder = "$HOME\Minecraft Backups",
    [Switch]$BackupAll,
    [String]$World,
    #Default file type for output backup is 7z
    [ValidateSet("7z","zip","gzip","bzip2","tar")]
    [String]$FileType = "7z"
)

    #Select Minecraft Version
    if($MinecraftVersion -eq "Bedrock"){
        $minecraft_worlds_folder = "$HOME\AppData\Local\Packages\Microsoft.MinecraftUWP_8wekyb3d8bbwe\LocalState\games\com.mojang\minecraftWorlds"
    }elseif($MinecraftVersion -eq "Java"){
        $minecraft_worlds_folder = "$HOME\AppData\Roaming\.minecraft\saves"
    }
    
    
    #The option for change the output file format its pendient
    # #Select file output type if it's not default
    # if(($FileType -ne "7z") -or ($FileType -ne "zip") -or ($FileType -ne "gzip") -or ($FileType -ne "bzip2") -or ($FileType -ne "tar")){
    # }
    
    function Get-WorldList {
        $worldlist = @{}
        foreach ($item in Get-ChildItem -Path $minecraft_worlds_folder -Directory) {
            $folderFullPath = $item.FullName
            $worldName      = ''
    
            switch ($MinecraftVersion) {
    
                'Bedrock' {
                    # The real world name is the first line of levelname.txt
                    $levelTxt = Join-Path -Path $folderFullPath -ChildPath 'levelname.txt'
                    if (Test-Path -LiteralPath $levelTxt) {
                        $worldName = (Get-Content -LiteralPath $levelTxt -First 1).Trim()
                    }
    
                    # Fallback to the folder name if levelname.txt is missing / empty
                    if (-not $worldName) { $worldName = $item.Name }
                }
    
                'Java' {
                    # For Java Edition the folder name *is* the world name
                    $worldName = $item.Name
                }
    
                default {
                    # Future-proof: if some other edition string is ever passed
                    $worldName = $item.Name
                }
            }
    
            # ---- Duplicate-name protection ------------------------------------
            $uniqueName = $worldName
            $i = 1
            while ($worldlist.ContainsKey($uniqueName)) {
                $uniqueName = "$worldName ($i)"
                $i++
            }
            # -------------------------------------------------------------------
    
            # Add / overwrite entry (never throws on duplicates)
            $worldlist[$uniqueName] = $folderFullPath
        }
    
        return $worldlist        # Hashtable: keys = names, values = paths
    }
    
    Write-Host -ForegroundColor Yellow "Searching for worlds in the local folder..."
    $worldlist = Get-WorldList
    
    # If no worlds are founded the script exit
    if($worldlist.Count -lt 1){
        Write-Error "No worlds were founded!"
        exit
    }

    $date =  Get-Date -Format "ddMMyyyy-HHmmss"
    $output_filename = "$OutputFolder\$World-$date"
    
    if($BackupAll){
        $output_filename = "$OutputFolder\MyWorlds-$date"
        $worldBkp = $minecraft_worlds_folder
    }elseif($World -eq ""){
        do {
            $World = Read-Host -Prompt "Supply a world for the backup"
        } while ($World -eq "")
        $output_filename = "$OutputFolder\$World-$date"
    }
    
    #Checks if exists a world with the name given
    if($worldlist.ContainsKey($World)){
        $output_filename = "$OutputFolder\$World-$date"
        $worldBkp = $worldlist[$World]
        Write-Host -ForegroundColor Green "The world $World was founded!"
    }
    
    Write-Host -ForegroundColor Green "Compressing the World..."
    #Check if 7zip its installed
    if(Test-Path "C:\Program Files\7-Zip\7z.exe"){
        #you can specify another path for 7zip installation
        Set-Alias -Name Compress -Value "C:\Program Files\7-Zip\7z.exe"
        Compress a -t"$FileType" "$output_filename.$FileType" "$worldBkp" -mx=9 -mmt=on > $null
    }else {
        Write-Host -ForegroundColor Yellow "7zip it's not installed, using Compress-Archive instead..."
        Compress-Archive -Path "$worldBkp" -DestinationPath "$output_filename.zip" > $null
    }
    
    if($LASTEXITCODE -eq 0){
        # Write-Host -ForegroundColor Green "Everything is ok"
        Write-Host -ForegroundColor Green "The backup was created successfully at $OutputFolder!"
    }else{
        Write-Error "The backup couldnt be created"
    }
