function New-CmnLogEntry {
    <#
    .SYNOPSIS
        Writes log Entry that can be read by CMTrace.exe

    .DESCRIPTION
        If you set 'LogEntries' to $true, it writes log entries to a file. If the file is larger then MaxFileSize, it will rename it to
        *yyyymmdd-HHmmss.log and start a new file. You can specify if it's an (1) informational, (2) warning, or (3) error message as well.
        It will also add time zone information, so if you have machines in multiple time zones, you can convert to UTC and make sure you kNow exactly
        when things happened.
        
        Will write to output if you specify the WriteOutput parameter

    .PARAMETER Entry
        This is the text that is the log Entry.

    .PARAMETER Type
        Defines the type of message, 1 = Informational (default), 2 = Warning, and 3 = Error.

    .PARAMETER Component
        Specifies the Component information. This could be the name of the function or thread, or whatever you like, to further help
        identify what is being logged.

    .PARAMETER LogFile
        File for writing logs to (default is C:\Windows\Logs\Software\error.log).

    .PARAMETER LogEntries
        Set to $true to write to the log file. Otherwise, it will just be write-verbose (default is $false).

    .PARAMETER MaxLogSize
        Max size for the log (default is 5MB).

    .PARAMETER MaxLogHistory
        Specifies the number of history log files to keep (default is 5).

    .PARAMETER WriteOutput
        Write Output to screen also. Default is $false

    .EXAMPLE
        New-CmnLogEntry -Entry "Machine $computerName needs a restart." -Type 2 -Component 'Installer' -LogFile $LogFile -LogEntries -MaxLogSize 10485760

        This will add a warning Entry, after expanding $computerName from the compontent Installer to the Logfile and roll it over if it exceeds 10MB

    .LINK
        http://configman-notes.com

    .NOTES
        Author:     James Parris
        Contact:    jim@ConfigMan-Notes.com
        Created:    2016-03-22
        Updated:    2017-03-01  Added log rollover
                    2018-10-23  Added Write-Verbose
                                Added adjustment in TimeZond for Daylight Savings Time
                                Corrected time format for renaming logs because I'm an idiot and put 3 digits in the minute field.
                    2022-07-01  Changed Write-Verbose to WriteOutput
                    2024-01-10  Changed Write-Output to Write-Host to prevent errors. Also color coded messages
                    2024-02-24  Cleaned up comments
        PSVer:	    3.0
        Version:    2.0
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true, HelpMessage = 'This is the text that is the log Entry.')]
        [String]$Entry,

        [Parameter(Mandatory = $false, HelpMessage = 'Defines the Type of message, 1 = Informational (default), 2 = Warning, and 3 = Error.')]
        [ValidateSet(1, 2, 3)]
        [INT32]$Type = 1,

        [Parameter(Mandatory = $true, HelpMessage = 'Specifies the Component information. This could be the name of the function or thread, or whatever you like, to further help identify what is being logged.')]
        [String]$Component,

        [Parameter(Mandatory = $false, HelpMessage = 'Date of Entry')]
        [datetime]$Now = (Get-Date),

        [Parameter(Mandatory = $false, HelpMessage = 'File for writing logs to (default is C:\Windows\Logs\Software\error.log).')]
        [String]$LogFile = 'C:\Windows\Logs\Software\error.log',

        [Parameter(Mandatory = $false, HelpMessage = 'Set to $true to write to the log file. Otherwise, it will just be write-verbose (default is $false).')]
        [Boolean]$LogEntries = $true,

        [Parameter(Mandatory = $false, HelpMessage = 'Max size for the log (default is 5MB).')]
        [Int]$MaxLogSize = 5242880,

        [Parameter(Mandatory = $false, HelpMessage = 'Specifies the number of history log files to keep (default is 5).')]
        [Int]$MaxLogHistory = 5,

        [Parameter(Mandatory = $false, HelpMessage = 'Writes output to screen also. Default is $false')]
        [boolean]$WriteOutput = $false
    )

    # Make sure directory for log exists
    $LogDir = Split-Path -Path $LogFile
    if (-not (Test-Path -Path $LogDir)) { 
        Set-CmnPath @NewLogEntry -path $LogDir
    }
    # Get Timezone info
    $TzInfo = [System.TimeZoneInfo]::Local
    
    # Get Timezone Offset
    $TzOffset = $TzInfo.BaseUTcOffset.Negate().TotalMinutes
    
    # If it's daylight savings time, we need to adjust
    if ($TzInfo.IsDaylightSavingTime($Now)) {
        $TzAdjust = ((($TzInfo.GetAdjustmentRules()).DaylightDelta).TotalMinutes)[0]
        $TzOffset -= $TzAdjust
    } # End if

    # Now, to figure out the format. if the timezone adjustment is posative, we need to represent it as +###
    if ($TzOffset -ge 0) {
        $TzOffset = "$(Get-Date -Format 'HH:mm:ss.fff')+$($TzOffset)"
    } # End if

    # Otherwise, we need to represent it as -###
    else {
        $TzOffset = "$(Get-Date -Format 'HH:mm:ss.fff')$TzOffset"
    } # ENd else

    # Create Entry line, properly formatted
    $CmEntry = '<![LOG[{0}]LOG]!><time="{2}" date="{1}" component="{5}" context="" type="{4}" thread="{3}">' -f $Entry, (Get-Date $Now -Format 'MM-dd-yyyy'), $TzOffset, $pid, $Type, $Component

    if ($LogEntries) {
        # Now, see if we need to roll the log
        if (Test-Path $LogFile) {
            # File exists, Now to check the size
            if ((Get-Item -Path $LogFile).Length -gt $MaxLogSize) {
                # Rename file
                $BackupLog = ($LogFile -replace '\.log$', '') + "-$(Get-Date -Format 'yyyymmdd-HHmmss').log"
                Rename-Item -Path $LogFile -NewName $BackupLog -Force
                # Get filter information
                # First, we do a regex search, and just get the text before the .log and after the \
                $LogFile -match '(\w*).log' | Out-Null
                # Now, we add a trailing * for the filter
                $LogFileName = "$($Matches[1])*"
                # Get the path for the log so we kNow where to search
                $LogPath = Split-Path -Path $LogFile
                # And we remove any extra rollover logs.
                Get-ChildItem -Path $LogPath -Filter $LogFileName | Where-Object { $_.Name -notin (Get-ChildItem -Path $LogPath -Filter $LogFileName | Sort-Object -Property LastWriteTime -Descending | Select-Object -First $MaxLogHistory).name } | Remove-Item
            } # End if
        } # End if

        # Finally, we write the Entry
        $CmEntry | Out-File $LogFile -Append -Encoding ascii
    } # End if

    # Write to screen if requested
    if ($WriteOutput) {
        switch ($Type) {
            1 {
                Write-Host $Entry -ForegroundColor Green
            }
            2 {
                Write-Host $Entry -ForegroundColor Yellow
            }
            3 {
                Write-Host $Entry -ForegroundColor Red
            }
            Default {
                Write-Host $Entry
            }
        }
    } # End if
    # Also, we write verbose, just incase that's turned on.
    Write-Verbose $Entry
}