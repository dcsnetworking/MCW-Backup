# MCW-Backup

A Powershell script that automate the process of create backups for your Minecraft worlds, both Bedrock and Java Edition.

## Getting started

### Dependencies

You need to have installed [7zip](https://www.7-zip.org/download.html) to use the option `-FileType` or create backups bigger than 2GB of size, if it's not, the cmdlet `Compress-Archive` will be used instead (ZIP only).

### Download

Go and click on the green button "Code" and select the option "Download ZIP" or if you have `git` installed then can clone the repository with:

`git clone https://github.com/kevin-luna/MCW-Backup.git`

### Usage

#### Parameters

- `-MinecraftVersion`: Set the Minecraft Version for the worlds to be backed-up, it's always required for the script working.The posible options are `Bedrock` or `Java`.

- `-OutputFolder`: Set the output path for the backup file. The default value is `$HOME\Minecraft Backups` and also can be changed from the source. If the folder does not exist it'll be created.

- `-BackupAll`: If it's set, a backup of all the worlds existing for the selected version will be created; also the `-World` option will not can be used.

- `-World`: If it's set, only will be created a backup for the world with the name given of the selected version.

- `-FileType`: If 7zip it's installed you can select from the diferent format files supported: `7z, zip, gzip, bzip2, tar`. The default value is `7z`. If 7zip it's not installed the `zip` format and PowerShell's `Compress-Archive` will be used.

- `-Xuid` (Bedrock only, optional): The XUID of the Bedrock user profile to back up. If this is set and the folder exists, that world folder is selected directly and non-interactively. If the path does not exist, the script auto-detects as usual. Example XUID: `9999999999999999999`.

- `-NonInteractive` (Bedrock only, optional, switch): For scheduled or fully automated runs: if multiple Bedrock Users\<XUID> candidates exist, the script will choose one automatically instead of prompting. It picks the candidate with the most recent world subfolder (last modification time). Candidates with no world folders are ignored if any candidate has worlds. Use `-Xuid` instead if you want to specify exactly which user to back up.

---

#### Bedrock world folder detection (new behavior)

  Starting with Bedrock 1.21.120, worlds now reside in a new folder layout:
  
      %USERPROFILE%\AppData\Roaming\Minecraft Bedrock\Users\<XUID>\games\com.mojang\minecraftWorlds
    
  The script now:
  
  - Prefers the new layout above when present
  - If not found, falls back to the legacy UWP layout:  
      %USERPROFILE%\AppData\Local\Packages\Microsoft.MinecraftUWP_8wekyb3d8bbwe\LocalState\games\com.mojang\minecraftWorlds

  Detection and selection logic:
  
  - If `-Xuid` is set, and a folder for that XUID exists, it is used immediately.
  - Otherwise, ALL `<XUID>` folders are checked:
      - If only one candidate exists, it is used.
      - If multiple candidates exist and `-NonInteractive` is specified, the script inspects world subfolders within each:
          - It will only consider candidates that have at least one world folder (subfolder).
          - It selects the candidate whose newest world folder (by LastWriteTime) is the most recently updated.
          - If none have any world folders, the script selects the most recently updated candidate folder as a last resort.
      - If multiple candidates exist but `-NonInteractive` is NOT set, the user is prompted to choose which to use.
  - If nothing is found in the new layout, the script falls back to the legacy UWP folder.

---

#### Examples

Create a backup of your entire Minecraft Worlds folder for Minecraft Bedrock Edition and will store it at `D:\My Worlds Backup` folder.

    .\MCW-Backup -MinecraftVersion Bedrock -BackupAll -OutputFolder 'D:\My Worlds Backup'

Create a backup of your entire Minecraft Worlds folder for Minecraft Java Edition and will store it at default folder (`$HOME\Minecraft Backups`).

    .\MCW-Backup -MinecraftVersion Java -BackupAll

Create a backup of the world 'My World' for Minecraft Java Edition and will store it at default folder (`$HOME\Minecraft Backups`).

    .\MCW-Backup -MinecraftVersion Java -World 'My World'

Non-interactive, auto-pick the most-recent XUID's worlds and back up all worlds:

    .\MCW-Backup.ps1 -MinecraftVersion Bedrock -NonInteractive -BackupAll -OutputFolder "C:\Backups"

Non-interactive, specify XUID explicitly (useful in scheduled tasks):

    .\MCW-Backup.ps1 -MinecraftVersion Bedrock -Xuid 9999999999999999999 -BackupAll -FileType 7z

---

## Troubleshooting

- "No worlds were found!" â€” common causes:
    - The chosen `minecraftWorlds` folder does not exist or is inaccessible (permissions).
    - For Bedrock: the selected XUID folder may be empty (no world subfolders). If another XUID contains worlds, use `-NonInteractive` (the script will ignore empty candidates) or supply `-Xuid` for the correct XUID.
    - Make sure to run the script as the same Windows user who owns the Bedrock profile folders when checking `Users\<XUID>` entries.

- If the script reports candidate folders but `Get-ChildItem` shows no directory entries, try running PowerShell as the same user who runs Minecraft.

---

## Commit log for the current change

- Prefer new Bedrock path (1.21.120) over legacy UWP path.
- Add `-Xuid` parameter for explicit Bedrock user folder selection.
- Add `-NonInteractive` switch and logic to automatically pick the best XUID:
    - Chooses the candidate with the newest world subfolder timestamp.
    - Ignores empty `minecraftWorlds` when other XUIDs contain worlds.
    - Falls back to newest candidate folder LastWriteTime if all are empty; fallback to legacy path if nothing else found.
- Improved detection and documentation.
