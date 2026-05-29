[CmdletBinding()]

<#TODO: Update Help
    .SYNOPSIS
        Synopsis goes here

    .DESCRIPTION
        Description goes here

    .PARAMETER LogFile
        File for writing logs to (default is C:\Windows\Logs\Software\<ScriptName>.log).

    .PARAMETER LogEntries
        Set to $true to write to the log file. Otherwise, it will just be New-CmnLogEntry -Entry (default is $false).

    .PARAMETER MaxLogSize
        Max size for the log (default is 5MB).

    .PARAMETER MaxLogHistory
        Specifies the number of history log files to keep (default is 5).

    .PARAMETER WriteOutput
            Write Output to screen also

    .EXAMPLE

    .LINK
        http://configman-notes.com

    .NOTES
        Author:	    Jim Parris
        Email:	    James_Parris@Dell.com
        Version:    1.0.0		
        Date:	    20250328 #TODO: Set Date
        Updated:
#>

[CmdletBinding()]

param (
    [Parameter(Mandatory = $false, HelpMessage = 'File for writing logs to (default is C:\Windows\Logs\Software\<ScriptName>.log).')]
    [String]$LogFile,
    
    [Parameter(Mandatory = $false, HelpMessage = 'Set to $true to write to the log file. Otherwise, it will just be write-verbose (default is $false).')]
    [Boolean]$LogEntries = $false,

    [Parameter(Mandatory = $false, HelpMessage = 'Max size for the log (default is 5MB).')]
    [Int]$MaxLogSize = 5242880,
    
    [Parameter(Mandatory = $false, HelpMessage = 'Specifies the number of history log files to keep (default is 5).')]
    [Int]$MaxLogHistory = 5,
    
    [Parameter(Mandatory = $false, HelpMessage = 'Writes output to screen also')]
    [boolean]$WriteOutput = $false
)

Get-ChildItem -Path '.\Functions' -Filter '*.ps1' | ForEach-Object {. $_.FullName}

# Ensure we have log file name
if ($null -eq $LogFile -or $LogFile -eq '') {
    $logPath = "$($env:WinDir)\Logs\Software"
    $logName = (Split-Path -Path $PSCommandPath -Leaf).Replace('ps1', 'log')
    $LogFile = "$($logPath)$($logName)"
}

$NewLogEntry = @{
    LogFile       = $LogFile;
    Component     = 'Optimize-CmnMedia'
    LogEntries    = $LogEntries;
    MaxLogSize    = $MaxLogSize;
    MaxLogHistory = $MaxLogHistory;
    WriteOutput   = $writeOutput;
}

# Log variables
New-CmnLogEntry @NewLogEntry -Type 1 -Entry "LogFile       = $LogFile"
New-CmnLogEntry @NewLogEntry -Type 1 -Entry "LogEntries    = $LogEntries"
New-CmnLogEntry @NewLogEntry -Type 1 -Entry "MaxLogSize    = $MaxLogSize"
New-CmnLogEntry @NewLogEntry -Type 1 -Entry "MaxLogHistory = $MaxLogHistory"
New-CmnLogEntry @NewLogEntry -Type 1 -Entry "writeOutput   = $writeOutput"
# Get list of files in the source directory
# Get list of files in the cleanup directory
# Search for matches and delete
New-CmnLogEntry @NewLogEntry -Type 1 -Entry 'Finished'