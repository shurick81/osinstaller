# Preparing USB drives for installing OS

## Windows

1. Run diskpart with administrative priviledges and paste for UEFI:

```
select disk 2
clean
RESCAN
create partition primary
format quick fs=FAT32 label="WinInstall"
active
assign letter=E
Exit
```

For BIOS:
```
select disk 2
clean
RESCAN
create partition primary
format quick fs=NTFS label="WinInstall"
active
assign letter=E
Exit
```

2. Run in PowerShell with administrative priviledges:

```PowerShell
$targetDriveLetter = "E";
$osCode = "Win10ProEng";
$bootType = "UEFI";
$dictonary = Import-PowershellDataFile .\dictionary.psd1;
$osDictionary = $dictonary.$osCode;
$localFileName = $osDictionary.LocalFileName;
$localFilePath = ( Get-Location ).Path + "\" + $localFileName;

Write-Host "Checking local image file";
if ( !( Get-Item .\$localFileName -ErrorAction Ignore ) )
{
    Start-BitsTransfer -Source $osDictionary.URL -Destination .\$localFileName;
}

$updateLocalFileName = $osDictionary.UpdateLocalFileName;
Write-Host "Checking local update file";
if ( !( Get-Item .\$updateLocalFileName -ErrorAction Ignore ) )
{
    Invoke-RestMethod -Uri $osDictionary.UpdateURL -OutFile .\$updateLocalFileName;
}

Write-Host "Mounting image file";
$mountResult = Mount-DiskImage $localFilePath -PassThru;
$driveLetter = ( $mountResult | Get-Volume ).DriveLetter;
Get-PSDrive > $null
Write-Host "Waiting while files are ready on $driveLetter drive";
Do {
    $driveFiles = $null;
    $temp = Start-Sleep 5;
    $driveFiles = Get-ChildItem "$driveLetter`:\*" -Recurse -ErrorAction SilentlyContinue;
} Until ( $driveFiles )

Write-Host "Copying installation files";
Get-Item "$driveLetter`:\*" | ? { $_.Name -ne "autorun.inf" } | Copy-Item -Destination "e:" -Recurse -Container -Force

Write-Host "Dismounting image file";
Dismount-DiskImage -ImagePath $localFilePath;

Write-Host "Copying Update file";
New-Item -Path "$targetDriveLetter`:\Updates" -ItemType Directory -Force | Out-Null
Copy-Item -Path ".\$updateLocalFileName" -Destination "$targetDriveLetter`:\Updates" -Force

Copy-Item -Path ".\answerfiles\$osCode\$bootType\Autounattend.xml" -Destination "$targetDriveLetter`:" -Force
```

3. Boot via UEFI or BIOS according to the parameter $bootType above