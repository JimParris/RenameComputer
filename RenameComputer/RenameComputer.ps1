<#
PSScriptInfo

.VERSION 1.1

.GUID 3b42d8c8-cda5-4411-a623-90d812a8e29e

.AUTHOR Michael Niehaus

.COMPANYNAME

.COPYRIGHT

.TAGS

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
Version 1.0: Initial version.

.PRIVATEDATA

.DESCRIPTION 
Rename the computer using the logic contained in this script.  This will work for AD or AAD-joined devices, or even workgroup machines.
Note that if the device is joined to AD, there must be connectivity to the domain and the computer must have the rights to rename itself.

#> 

Param()

# If we are running as a 32-bit process on an x64 system, re-launch as a 64-bit process
if ("$env:PROCESSOR_ARCHITEW6432" -ne 'ARM64') {
    if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe") {
        & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy bypass -File "$PSCommandPath"
        Exit $lastexitcode
    }
}

# Create a tag file just so Intune knows this was installed
if (-not (Test-Path "$($env:ProgramData)\Microsoft\RenameComputer")) {
    mkdir "$($env:ProgramData)\Microsoft\RenameComputer"
}
Set-Content -Path "$($env:ProgramData)\Microsoft\RenameComputer\RenameComputer.ps1.tag" -Value 'Installed'

# Initialization
$dest = "$($env:ProgramData)\Microsoft\RenameComputer"
if (-not (Test-Path $dest)) {
    mkdir $dest
}
Start-Transcript "$dest\RenameComputer.log" -Append

# See if we are AD or AAD joined
$details = Get-ComputerInfo
$isAD = $false
$isAAD = $false
if ($details.CsPartOfDomain) {
    Write-Host "Device is joined to AD domain: $($details.CsDomain)"
    $isAD = $true
    $goodToGo = $false
}
else {
    $goodToGo = $true
    $subKey = Get-Item 'HKLM:/SYSTEM/CurrentControlSet/Control/CloudDomainJoin/JoinInfo'
    $guids = $subKey.GetSubKeyNames()
    foreach ($guid in $guids) {
        $guidSubKey = $subKey.OpenSubKey($guid)
        $tenantId = $guidSubKey.GetValue('TenantId')
    }
    if ($null -ne $tenantID) {
        Write-Host "Device is joined to AAD tenant: $tenantID"
        $isAAD = $true
    }
    else {
        Write-Host 'Not part of a AAD or AD, in a workgroup.'
    }
}

# Make sure we have connectivity
$goodToGo = $true
if ($isAD) {
    $dcInfo = [ADSI]'LDAP://RootDSE'
    if ($null -eq $dcInfo.dnsHostName) {
        Write-Host 'No connectivity to the domain, unable to rename at this point.'
        $goodToGo = $false
    }
}

# Good to go, we can rename the computer
if ($goodToGo) {
    # Remove the scheduled task (if it exists)
    Disable-ScheduledTask -TaskName 'RenameComputer' -ErrorAction Ignore
    Unregister-ScheduledTask -TaskName 'RenameComputer' -Confirm:$false -ErrorAction Ignore
    Write-Host 'Scheduled task unregistered.'

    # Get the new computer name: use the asset tag (maximum of 13 characters), or the 
    # serial number if no asset tag is available (replace this logic if you want)
    $systemEnclosure = Get-CimInstance -ClassName Win32_SystemEnclosure
    if (($null -eq $systemEnclosure.SMBIOSAssetTag) -or ($systemEnclosure.SMBIOSAssetTag -eq '')) {
        $assetTag = $details.BiosSerialNumber
    }
    else {
        $assetTag = $systemEnclosure.SMBIOSAssetTag
    }
    if ($assetTag.Length -gt 13) {
        $assetTag = $assetTag.Substring(0, 13)
    }
    if ($details.CsPCSystemTypeEx -eq 1) {
        $newName = "D-$assetTag"
    }
    else {
        $newName = "L-$assetTag"
    }

    # Is the computer name already set?  If so, bail out
    if ($newName -ieq $details.CsName) {
        Write-Host "No need to rename computer, name is already set to $newName"
        Stop-Transcript
        Exit 0
    }

    # Set the computer name
    Write-Host "Renaming computer to $($newName)"
    Rename-Computer -NewName $newName

    # Make sure we reboot if still in ESP/OOBE by reporting a 1641 return code (hard reboot)
    if ($details.CsUserName -match 'defaultUser') {
        Write-Host 'Exiting during ESP/OOBE with return code 1641'
        Stop-Transcript
        Exit 1641
    }
    else {
        Write-Host 'Initiating a restart in 10 minutes'
        & shutdown.exe /g /t 600 /f /c 'Restarting the computer due to a computer name change.  Save your work.'
        Stop-Transcript
        Exit 0
    }
}
else {
    # Check to see if already scheduled
    $existingTask = Get-ScheduledTask -TaskName 'RenameComputer' -ErrorAction SilentlyContinue
    if ($null -ne $existingTask) {
        Write-Host 'Scheduled task already exists.'
        Stop-Transcript
        Exit 0
    }

    # Copy myself to a safe place if not already there
    if (-not (Test-Path "$dest\RenameComputer.ps1")) {
        Copy-Item $PSCommandPath "$dest\RenameComputer.PS1"
    }

    # Create the scheduled task action
    $action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument "-NoProfile -ExecutionPolicy bypass -WindowStyle Hidden -File $dest\RenameComputer.ps1"

    # Create the scheduled task trigger
    $timespan = New-TimeSpan -Minutes 5
    $triggers = @()
    $triggers += New-ScheduledTaskTrigger -Daily -At 9am
    $triggers += New-ScheduledTaskTrigger -AtLogOn -RandomDelay $timespan
    $triggers += New-ScheduledTaskTrigger -AtStartup -RandomDelay $timespan
    
    # Register the scheduled task
    Register-ScheduledTask -User SYSTEM -Action $action -Trigger $triggers -TaskName 'RenameComputer' -Description 'RenameComputer' -Force
    Write-Host 'Scheduled task created.'
}

Stop-Transcript
