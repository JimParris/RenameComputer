function Set-CmnPath {
    <#
    .SYNOPSIS
        Checks if path exists, if not, creates it.

    .DESCRIPTION
        Checks if path exists, if not, creates it.

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
        Date:	    01-29-2025
        Updated:
    #>

    [CmdletBinding()]
    PARAM(
        [String]$Path,

        [Parameter(Mandatory = $false, HelpMessage = 'File for writing logs to (default is C:\Windows\Temp\Dell\Logs\<scriptName>.log).')]
        [String]$LogFile,
            
        [Parameter(Mandatory = $false, HelpMessage = 'Set to $true to write to the log file. Otherwise, it will just be write-verbose (default is $false).')]
        [Boolean]$LogEntries = $true,

        [Parameter(Mandatory = $false)]
        [string]$Component,
            
        [Parameter(Mandatory = $false, HelpMessage = 'Max size for the log (default is 5MB).')]
        [Int]$MaxLogSize = 5242880,
            
        [Parameter(Mandatory = $false, HelpMessage = 'Specifies the number of history log files to keep (default is 5).')]
        [Int]$MaxLogHistory = 5,
            
        [Parameter(Mandatory = $false, HelpMessage = 'Writes output to screen also')]
        [boolean]$WriteOutput = $true
    )

    begin {
        # Ensure we have log file name
        if ($null -eq $LogFile -or $LogFile -eq '') {
            $LogPath = "$($env:WinDir)\Logs\Software\"
            $LogName = (Split-Path -Path $PSCommandPath -Leaf).Replace('ps1', 'log')
            $LogFile = "$($LogPath)$($LogName)"
        }
    }
    
    process {
        # First, see if the Path exists
        if (-not (Test-Path $Path)) {
            $Paths = $Path.Split('\')
            $PathToCheck = $Paths[0]
            for ($x = 1; $x -lt $Paths.Count; $x++) {
                $PathToCheck = "$PathToCheck\$($Paths[$x])"
                if (!(Test-Path -Path $PathToCheck)) {
                    New-Item -Path $PathToCheck -ItemType Container | Out-Null 
                }
            }
        }
    }

    end {
    }
}