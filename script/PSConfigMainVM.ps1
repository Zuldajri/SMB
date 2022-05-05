[CmdletBinding()]

Param(
    [string] $VMName, 
    [string] $PrimaryUseDataDisk,
    [string] $StorageAccountName,
    [string] $StorageAccountKey,
    [string] $FileShareType,
    [string] $FileShareName,
    [string] $DomainMethod
 )

$osDrive = ((Get-WmiObject Win32_OperatingSystem).SystemDrive).TrimEnd(":")
$size = (Get-Partition -DriveLetter $osDrive).Size
$maxSize = (Get-PartitionSupportedSize -DriveLetter $osDrive).SizeMax
if ($size -lt $maxSize){
     Resize-Partition -DriveLetter $osDrive -Size $maxSize
}


if ($PrimaryUseDataDisk -eq 'True'){
    #Initialize Data Disks
    Get-Disk | ` 
    Where partitionstyle -eq 'raw' | ` 
    Initialize-Disk -PartitionStyle MBR -PassThru | ` 
    New-Partition -AssignDriveLetter -UseMaximumSize | ` 
    Format-Volume -FileSystem NTFS -NewFileSystemLabel "datadisk" -Confirm:$false
}

#Enable Time Zone Redirection
reg add "HKLM\Software\Policies\Microsoft\Windows NT\Terminal Services" /v fEnableTimeZoneRedirection  /t REG_DWORD /d 1 /f

if ($FileShareType -eq 'azFileShare'){
    #  Run the code below to test the connection and mount the share
    $connectTestResult = Test-NetConnection -ComputerName "$StorageAccountName.file.core.windows.net" -Port 445
    if ($connectTestResult.TcpTestSucceeded) {
        # Save the password so the drive will persist on reboot
        cmd.exe /C "cmdkey /add:`"$StorageAccountName.file.core.windows.net`" /user:`"localhost\$StorageAccountName`" /pass:`"$StorageAccountKey`""
        # Mount the drive
        New-PSDrive -Name Z -PSProvider FileSystem -Root "\\$StorageAccountName.file.core.windows.net\$FileShareName" -Persist
    } else {
        Write-Error -Message "Unable to reach the Azure storage account via port 445. Check to make sure your organization or ISP is not blocking port 445, or use Azure P2S VPN, Azure S2S VPN, or Express Route to tunnel SMB traffic over a different port."
    }
}
