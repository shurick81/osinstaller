# Preparing USB drives for installing OS

## Windows

1. Run in cmd with administrative priviledges and paste for UEFI:

```
diskpart
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
diskpart
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
```

3. Boot via UEFI or BIOS according to the parameter $bootType above