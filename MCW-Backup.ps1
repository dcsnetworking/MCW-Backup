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
    # Optional: explicitly pick a Bedrock Users\<XUID> folder (non-interactive)
    [String]$Xuid,
    # If set, script will not prompt when multiple XUID folders exist; it will pick the newest automatically.
    [Switch]$NonInteractive,
    #Default file type for output backup is 7z
    [ValidateSet("7z","zip","gzip","bzip2","tar")]
    [String]$FileType = "7z"
)

    #Select Minecraft Version
    if($MinecraftVersion -eq "Bedrock"){
        # Legacy (UWP) Bedrock location
        $legacyPath = Join-Path -Path $HOME -ChildPath "AppData\Local\Packages\Microsoft.MinecraftUWP_8wekyb3d8bbwe\LocalState\games\com.mojang\minecraftWorlds"

        # New Bedrock location introduced in the 1.21.200 update:
        # %USERPROFILE%\AppData\Roaming\Minecraft Bedrock\Users\<XUID>\games\com.mojang\minecraftWorlds
        $newUsersBase = Join-Path -Path $HOME -ChildPath "AppData\Roaming\Minecraft Bedrock\Users"

        # Collect candidate minecraftWorlds locations across all XUIDs (if present)
        $candidates = @()
        if (Test-Path -LiteralPath $newUsersBase) {
            foreach ($userDir in Get-ChildItem -LiteralPath $newUsersBase -Directory -ErrorAction SilentlyContinue) {
                $candidate = Join-Path -Path $userDir.FullName -ChildPath "games\com.mojang\minecraftWorlds"
                if (Test-Path -LiteralPath $candidate) {
                    $candidates += $candidate
                }
            }
        }

        # If an XUID was provided, prefer it (non-interactive)
        if (-not [string]::IsNullOrEmpty($Xuid)) {
            $providedUserFolder = Join-Path -Path $newUsersBase -ChildPath $Xuid
            $providedCandidate = Join-Path -Path $providedUserFolder -ChildPath "games\com.mojang\minecraftWorlds"
            if (Test-Path -LiteralPath $providedCandidate) {
                $minecraft_worlds_folder = $providedCandidate
                Write-Host -ForegroundColor Green "Using Bedrock worlds for provided XUID: $Xuid -> $minecraft_worlds_folder"
            } else {
                Write-Warning "Provided XUID path was not found: $providedCandidate. Falling back to auto-detection."
            }
        }

        # If XUID didn't set a folder, perform detection and selection.
        if (-not $minecraft_worlds_folder) {
            # Prefer the new path when it exists (per your request).
            if ($candidates.Count -gt 0) {
                if ($candidates.Count -eq 1) {
                    $minecraft_worlds_folder = $candidates[0]
                    Write-Host -ForegroundColor Green "Found Bedrock worlds at (new path): $minecraft_worlds_folder"
                } else {
                    # Multiple candidates found
                    if ($NonInteractive.IsPresent) {
                        # NEW BEHAVIOR:
                        # - Inspect subfolders (world folders) inside each candidate.
                        # - Prefer candidates that actually contain world subfolders.
                        # - Among candidates that contain subfolders, pick the one whose newest subfolder LastWriteTime is the most recent.
                        # - If none of the candidates contain subfolders, fall back to candidate folder LastWriteTime.
                        $candidatesWithWorlds = @()
                        $candidatesWithoutWorlds = @()

                        foreach ($candidatePath in $candidates) {
                            try {
                                $subfolders = Get-ChildItem -LiteralPath $candidatePath -Force -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer }
                                if ($subfolders -and $subfolders.Count -gt 0) {
                                    # determine newest LastWriteTime among subfolders (worlds)
                                    $newestSub = $subfolders | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                                    $candidatesWithWorlds += [PSCustomObject]@{
                                        Path = $candidatePath
                                        NewestWorldTime = $newestSub.LastWriteTime
                                    }
                                } else {
                                    # record empty candidate for potential fallback
                                    $item = Get-Item -LiteralPath $candidatePath -ErrorAction SilentlyContinue
                                    $candidatesWithoutWorlds += [PSCustomObject]@{
                                        Path = $candidatePath
                                        FolderTime = if ($item) { $item.LastWriteTime } else { [datetime]::MinValue }
                                    }
                                }
                            } catch {
                                Write-Warning "Error inspecting candidate '$candidatePath': $_"
                            }
                        }

                        if ($candidatesWithWorlds.Count -gt 0) {
                            # pick the candidate with the most recent world subfolder timestamp
                            $chosen = $candidatesWithWorlds | Sort-Object NewestWorldTime -Descending | Select-Object -First 1
                            $minecraft_worlds_folder = $chosen.Path
                            Write-Host -ForegroundColor Green "NonInteractive: selected Bedrock user folder by newest world subfolder datestamp: $minecraft_worlds_folder (newest world activity: $($chosen.NewestWorldTime))"
                        } elseif ($candidatesWithoutWorlds.Count -gt 0) {
                            # No candidate contained worlds. Fall back to newest candidate folder timestamp.
                            $chosen = $candidatesWithoutWorlds | Sort-Object FolderTime -Descending | Select-Object -First 1
                            $minecraft_worlds_folder = $chosen.Path
                            Write-Host -ForegroundColor Yellow "NonInteractive: no world subfolders found in any candidate; selected newest candidate folder: $minecraft_worlds_folder (timestamp: $($chosen.FolderTime))"
                        } else {
                            Write-Warning "NonInteractive selection failed to determine a best candidate. Falling back to legacy path if available."
                        }
                    } else {
                        Write-Host -ForegroundColor Yellow "Multiple Bedrock user folders found. Please choose which one to use:"
                        for ($i = 0; $i -lt $candidates.Count; $i++) {
                            Write-Host "[$($i + 1)] $($candidates[$i])"
                        }
                        do {
                            $sel = Read-Host -Prompt "Enter the number of the folder to use"
                            $parsed = $null
                            [int]::TryParse($sel, [ref]$parsed) | Out-Null
                        } while (-not $parsed -or $parsed -lt 1 -or $parsed -gt $candidates.Count)
                        $minecraft_worlds_folder = $candidates[$parsed - 1]
                        Write-Host -ForegroundColor Green "Using: $minecraft_worlds_folder"
                    }
                }
            }

            # If no new-path candidates found or selection didn't pick one, fall back to legacy UWP path
            if (-not $minecraft_worlds_folder) {
                if (Test-Path -LiteralPath $legacyPath) {
                    $minecraft_worlds_folder = $legacyPath
                    Write-Host -ForegroundColor Green "Found Bedrock worlds at (legacy UWP): $minecraft_worlds_folder"
                } else {
                    Write-Warning "Could not find Bedrock worlds in either the new Users\<XUID> location or the legacy UWP location."
                    Write-Host -ForegroundColor Yellow "Checked: `n $newUsersBase\<XUID>\games\com.mojang\minecraftWorlds `n $legacyPath"
                    # leave $minecraft_worlds_folder unset (the rest of the script will error out more clearly)
                }
            }
        }
    } elseif($MinecraftVersion -eq "Java"){
        $minecraft_worlds_folder = "$HOME\AppData\Roaming\.minecraft\saves"
    }
    
    
    function Get-WorldList {
        $worldlist = @{}
        if (-not (Test-Path -LiteralPath $minecraft_worlds_folder)) {
            Write-Error "Worlds folder not found: $minecraft_worlds_folder"
            return $worldlist
        }

        # Use -Force and filter PSIsContainer to ensure we include hidden/system/reparse directories
        $items = Get-ChildItem -LiteralPath $minecraft_worlds_folder -Force -ErrorAction SilentlyContinue
        $dirItems = $items | Where-Object { $_.PSIsContainer }

        # If we found no directories, dump a helpful debug message showing what was found
        if (-not $dirItems -or $dirItems.Count -eq 0) {
            Write-Host -ForegroundColor Yellow "Warning: no subfolders detected under $minecraft_worlds_folder."
            if ($items -and $items.Count -gt 0) {
                Write-Host -ForegroundColor Yellow "Entries found (non-directory items or inaccessible):"
                foreach ($it in $items) {
                    Write-Host " - $($it.Name)  (PSIsContainer: $($it.PSIsContainer), LastWriteTime: $($it.LastWriteTime))"
                }
            } else {
                Write-Host -ForegroundColor Yellow "No entries at all were returned by Get-ChildItem for $minecraft_worlds_folder."
            }
            # Return empty list so caller reports "No worlds were found!" as before,
            # but the above output should help diagnose why.
            return $worldlist
        }

        foreach ($item in $dirItems) {
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
    
    # If no worlds are found the script exits
    if($worldlist.Count -lt 1){
        Write-Error "No worlds were found!"
        exit
    }

    $date =  Get-Date -Format "ddMMyyyy-HHmmss"
    $output_filename = "$OutputFolder\$World-$date"
    
    if($BackupAll){
        $output_filename = "$OutputFolder\MyWorlds-$date"
        $worldBkp = $minecraft_worlds_folder
    }elseif([string]::IsNullOrEmpty($World)){
        do {
            $World = Read-Host -Prompt "Supply a world for the backup"
        } while ([string]::IsNullOrEmpty($World))
        $output_filename = "$OutputFolder\$World-$date"
    }
    
    #Checks if exists a world with the name given
    if($worldlist.ContainsKey($World)){ 
        $output_filename = "$OutputFolder\$World-$date"
        $worldBkp = $worldlist[$World]
        Write-Host -ForegroundColor Green "The world $World was found!"
    }
    
    Write-Host -ForegroundColor Green "Compressing the World..."
    #Check if 7zip is installed
    if(Test-Path "C:\Program Files\7-Zip\7z.exe"){ 
        #you can specify another path for 7zip installation
        Set-Alias -Name Compress -Value "C:\Program Files\7-Zip\7z.exe"
        Compress a -t"$FileType" "$output_filename.$FileType" "$worldBkp" -mx=9 -mmt=on > $null
    }else {
        Write-Host -ForegroundColor Yellow "7zip is not installed, using Compress-Archive instead..."
        Compress-Archive -Path "$worldBkp" -DestinationPath "$output_filename.zip" > $null
    }
    
    if($LASTEXITCODE -eq 0){
        Write-Host -ForegroundColor Green "The backup was created successfully at $OutputFolder!"
    }else{
        Write-Error "The backup couldn't be created"
    }