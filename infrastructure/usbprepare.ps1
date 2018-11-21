function Ask-Letter ( $lettersToChoose )
{
    $input = Read-Host "Please select the disk. Note that the whole disk will be formatted and the data will be wiped."
    if ( $lettersToChoose -contains $input ) { return $input }
    return $null;
}
$config = Get-Content -Raw -Path .\usbprepare_config.json | ConvertFrom-Json;
$dictonary = Get-Content -Raw -Path .\dictionary.json | ConvertFrom-Json;

$osCode = $config.osCode;
$bootType = $config.bootType;

$lettersToChoose = @()
Get-Disk | ? { !$_.IsBoot } | % {
    Write-Host ( "Disk " + $_.Number + ", " + $_.FriendlyName + ", partitions:" );
    Get-Partition -DiskNumber $_.Number;
    $lettersToChoose += $_.Number;
}
if ( $lettersToChoose.Count -gt 0 )
{
    $targetDiskNumber = Ask-Letter $lettersToChoose;
    if ( $targetDiskNumber )
    {

        $osDictionary = $dictonary.$osCode;
        $localFileName = $osDictionary.LocalFileName;
        $localFilePath = ( Get-Location ).Path + "\" + $localFileName;

        Write-Host "Checking local image file $localFileName";
        if ( !( Get-Item .\$localFileName -ErrorAction Ignore ) )
        {
            Start-BitsTransfer -Source $osDictionary.URL -Destination .\$localFileName;
        }

        $updateLocalFileName = $osDictionary.UpdateLocalFileName;
        if ( $updateLocalFileName )
        {
            Write-Host "Checking local update file $updateLocalFileName";
            if ( !( Get-Item .\$updateLocalFileName -ErrorAction Ignore ) )
            {
                Invoke-RestMethod -Uri $osDictionary.UpdateURL -OutFile .\$updateLocalFileName;
            }
        }
        $fileName = [guid]::NewGuid().Guid;
        $filePath = "$env:Temp\$fileName";
        
        $diskpartScriptTemplateContent = Get-Content .\diskpartscripttemplate -Raw;
        if ( $config.bootType -eq "BIOS" )
        {
            $fileSystem = "NTFS"
        } else {
            $fileSystem = "FAT32"
        }
        [string]::Format( $diskpartScriptTemplateContent, $targetDiskNumber, $fileSystem ) | `
            Set-Content -Path $filePath;
        Write-Host "Running diskpart /s $filePath";
        diskpart /s $filePath;
        Sleep 30;
        $partition = Get-Partition -DiskNumber $targetDiskNumber;
        $targetDriveLetter = $partition.DriveLetter;
        Write-Host "targetDriveLetter: $targetDriveLetter"

        Write-Host "Mounting image file $localFilePath";
        $mountResult = Mount-DiskImage $localFilePath -PassThru;
        $driveLetter = ( $mountResult | Get-Volume ).DriveLetter;
        Get-PSDrive > $null
        Write-Host "Waiting while files are ready on $driveLetter drive";
        Do {
            $driveFiles = $null;
            $temp = Start-Sleep 5;
            $driveFiles = Get-ChildItem "$driveLetter`:\*" -Recurse -ErrorAction SilentlyContinue;
        } Until ( $driveFiles )

        Write-Host "Copying installation files from $driveLetter`: to $targetDriveLetter`:";
        Get-Item "$driveLetter`:\*" | ? { $_.Name -ne "autorun.inf" } | Copy-Item -Destination "$targetDriveLetter`:" -Recurse -Container -Force
        if ( $config.bootType -eq "UEFI" )
        {
            Start-Process -FilePath "Dism" -ArgumentList "/Split-Image /ImageFile:$driveLetter`:\sources\install.wim /SWMFile:$targetDriveLetter`:\sources\install.swm /FileSize:4096" -Wait -NoNewWindow;
        }
        
        Write-Host "Dismounting image file";
        Dismount-DiskImage -ImagePath $localFilePath;

        $updateLocalFileName = $osDictionary.UpdateLocalFileName;
        if ( $updateLocalFileName )
        {
            Write-Host "Copying Update file";
            New-Item -Path "$targetDriveLetter`:\Updates" -ItemType Directory -Force | Out-Null
            Copy-Item -Path ".\$updateLocalFileName" -Destination "$targetDriveLetter`:\Updates" -Force
        }

        Copy-Item -Path ".\answerfiles\$osCode\$bootType\Autounattend.xml" -Destination "$targetDriveLetter`:" -Force
    } else {
        Write-Host "Incorrect input, try again";
    }
} else {
    Write-Host "No drives to use";
}
