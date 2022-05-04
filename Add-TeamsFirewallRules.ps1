<#
  .NOTES
  Author: Mark Goodman
  Twitter: @silvermakrg
  Version 1.00
  Date: 04-May-2022

  Release Notes
  -------------
  Based on Michael Mardahl script https://github.com/mardahl/PSBucket/blob/master/Update-TeamsFWRules.ps1)

  Update History
  --------------
  1.00 (04-May-2022) - Initial script

  License
  -------
  MIT LICENSE
  
  Copyright (c) 2022 Mark Goodman (@silvermarkg)

  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation 
  files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, 
  modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the 
  Software is furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the 
  Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE 
  WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR 
  COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, 
  ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

  .SYNOPSIS
  Creates firewall rules for Microsoft Teams for specific user.
  Used a combination of original Microsoft script (https://docs.microsoft.com/en-us/microsoftteams/get-clients#sample-powershell-script)
  and modified script by  Michael Mardahl (https://github.com/mardahl/PSBucket/blob/master/Update-TeamsFWRules.ps1).

  .DESCRIPTION
  Designed to be run as user assigned PowerShell Script from Intune, or as a Scheduled Task run as SYSTEM at user login. 
  The script will create a new inbound firewall rules for Microsoft Teams for the currently logged in user.
  Implementation is based on Michael Mardahl blog https://msendpointmgr.com/2020/03/29/managing-microsoft-teams-firewall-requirements-with-intune/ 

  Script must be run with elevated permissions.

  .EXAMPLE
  Add-TeamsFirewallRules.ps1
	
	Description
	-----------
	Adds Microsoft Teams firewall rules to Windows Defender Firewall for current user.
#>

#region - Parameters
[Cmdletbinding(SupportsShouldProcess=$true,ConfirmImpact='Low')]
param()
#endregion - Parameters

#region - Script Environment
#Requires -Version 5
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
#endregion - Script Environment

#region - Functions
function Get-UserInfo() {
  <#
  .SYNOPSIS
  Attempts to get current logged on username and profile path
  .DESCRIPTION
  Uses the explorer.exe process to get the current logged on user, then looks up their profile path using the users SID
  as we are running as SYSTEM
  .EXAMPLE
  Get-UserInfo
  #>

  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  param ()

  begin {
    #-- Begin code only runs once --#
  }

  process {
    # Attempt to get logged on users profile path
    try {
      # Get current logged on user (using explorer.exe process is more reliable than Win32_ComputerSystem)
      $username = Get-Process -Name "explorer" -IncludeUserName | Select-Object -ExpandProperty username
      $userSID = (New-Object System.Security.Principal.NTAccount($username)).Translate([System.Security.Principal.SecurityIdentifier]).value
      $profilePath = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$($userSID)" -Name ProfileImagePath

      # Return username and profile path
      return [PSCustomObject]@{
        User        = $username
        ProfilePath = $profilePath
      }
    }
    catch [System.Exception] {
      $Message = "Failed to find users profile path. Error: $($_)"
      Throw $Message
    }
  }
}

function Remove-ProgramFirewallRule {
  <#
  .SYNOPSIS
  Removes any existing firewall rules that match the program path filter.
  .PARAMETER Path
  Specifies the full path to the program defined in the rules. This is used to search for matching rules to remove.
  .EXAMPLE
  Remove-ProgramFirewallRule -Path C:\Users\UserA\AppData\Local\Microsoft\Teams\Current\teams.exe

  Description
  -----------
  Removes any Windows Firewall rules referencing the path specified
  #>

  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  param (
    [Parameter(Mandatory=$true,Position=0)]
    [ValidateNotNullOrEmpty()]
    [String]$Path
  )

  begin {
    #-- Begin code only runs once --#
  }

  process {
    # Remove firewall rules matching path
    $Rules = Get-NetFirewallApplicationFilter -Program $Path -PolicyStore PersistentStore -ErrorAction SilentlyContinue | Get-NetFirewallRule
    foreach ($Rule in $Rules) {
      $Msg = "Deleting rule {0} [{1}]" -f $Rule.Name, $Rule.DisplayName
      Write-LogEntry -Message $Msg -Severity Information -Path $Script:LogPath
      $Rule | Remove-NetFirewallRule
    }
  }
}

function Add-TeamsFirewallRule {
  <#
  .SYNOPSIS
  Adds Microsoft Teams firewall rules for the user.
  .PARAMETER User
  Specifies the username to set the rules for. This is used for the rule name.
  .PARAMETER Path
  Specifies the full path to Microsoft Teams executable for the user.
  .EXAMPLE
  Add-TeamsFirewallRule -User UserA -Path C:\Users\UserA\AppData\Local\Microsoft\Teams\Current\teams.exe

  Description
  -----------
  Adds Microsoft Teams firewall rules for UserA
  #>

  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  param (
    [Parameter(Mandatory=$true,Position=0)]
    [ValidateNotNullOrEmpty()]
    [String]$User,
    
    [Parameter(Mandatory = $true, Position = 1)]
    [ValidateNotNullOrEmpty()]
    [String]$Path
  )

  begin {
    #-- Begin code only runs once --#
  }

  process {
    if (Test-Path -Path $Path -PathType Leaf) {
      $ruleName = "Microsoft Teams for user $($User)"
      "TCP", "UDP" | ForEach-Object {
        $Rule = New-NetFirewallRule -DisplayName "$($ruleName) ($($_)-In)" -Direction Inbound -Profile Domain,Private -Program $Path -Action Allow -Protocol $_
        $Msg = "Added rule {0} [{1}]" -f $Rule.Name, $Rule.DisplayName
        Write-LogEntry -Message $Msg -Severity Information -Path $Script:LogPath
      }
    }
  }    
}

function Write-LogEntry {
  <#
		.SYNOPSIS
		Writes a message to a log file.

		.DESCRIPTION
		Writes an infomational, warning or error meesage to a log file. Log entries can be written in basic (default) or cmtrace format.
        When using basic format, you can choose to include a date/time stamp if required.

		.PARAMETER Message
		THe message to write to the log file

		.PARAMETER Severity
		The severity of message to write to the log file. This can be Information, Warning or Error. Defaults to Information.

		.PARAMETER LogPath
		The path to the log file. Recommended to use Set-LogPath to set the path.

		#.PARAMETER AddDateTime (currently not supported)
		Adds a datetime stamp to each entry in the format YYYY-MM-DD HH:mm:ss.fff

		.EXAMPLE
        Write-LogEntry -Message "Searching for file" -Severity Information -LogPath C:\MyLog.log 

        Description
        -----------
        Writes a basic log entry

   		.EXAMPLE
        Write-LogEntry -Message "Searching for file" -Severity Warning -LogPath C:\MyLog.log -CMTraceFormat 

        Description
        -----------
        Writes a CMTrace format log entry
    #>

  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [String]$Message,

    [Parameter(Mandatory = $false, Position = 1, HelpMessage = "Severity for the log entry (Information, Warning or Error)")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet("Information", "Warning", "Error")]
    [String]$Severity = "Information",

    [Parameter(Mandatory = $true, Position = 2, HelpMessage = "The full path of the log file that the entry will written to")]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ (Test-Path -Path $_.Substring(0, $_.LastIndexOf("\")) -PathType Container) -and (Test-Path -Path $_ -PathType Leaf -IsValid) })]
    [String]$Path = $Script:LogPath,

    [Parameter(ParameterSetName = "CMTraceFormat", HelpMessage = "Indicates to use cmtrace compatible logging")]
    [Switch]$CMTraceFormat
  )

  # Construct date and time for log entry (based on currnent culture)
  $Date = Get-Date -Format (Get-Culture).DateTimeFormat.ShortDatePattern
  $Time = Get-Date -Format (Get-Culture).DateTimeFormat.LongTimePattern.Replace("ss", "ss.fff")

  # Determine parameter set
  if ($CMTraceFormat) {
    # Convert severity value
    switch ($Severity) {
      "Information" {
        $CMSeverity = 1
      }
      "Warning" {
        $CMSeverity = 2
      }
      "Error" {
        $CMSeverity = 3
      }
    }

    # Construct components for log entry
    $Component = (Get-PSCallStack)[1].Command
    $ScriptFile = $MyInvocation.ScriptName
  
    # Construct context for CM log entry
    $Context = $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
    $LogText = "<![LOG[$($Message)]LOG]!><time=""$($Time)"" date=""$($Date)"" component=""$($Component)"" context=""$($Context)"" type=""$($CMSeverity)"" thread=""$($PID)"" file=""$($ScriptFile)"">"
  }
  else {
    # Construct basic log entry
    $LogText = "[{0} {1}] {2}: {3}" -f $Date, $Time, $Severity, $Message
  }

  # Add value to log file
  try {
    Out-File -InputObject $LogText -Append -NoClobber -Encoding Default -FilePath $Script:LogPath -ErrorAction Stop
  }
  catch [System.Exception] {
    Write-Warning -Message "Unable to append log entry to $($Script:LogPath) file. Error message: $($_.Exception.Message)"
  }
}
#endregion - Functions

#region - Main code
#-- Script variables --#
# Use $PSScriptRoot for script path
$logFileName = Split-Path -Path ([System.IO.Path]::ChangeExtension($PSCommandPath, "log")) -Leaf
$WindowsTempPath = Join-Path -Path $env:SystemRoot -ChildPath Temp
$logPath = Join-Path -Path $WindowsTempPath -ChildPath $logFileName
$teamsProgramSuffix = "\AppData\Local\Microsoft\Teams\current\teams.exe"

#-- Main code --#
# Start logging
Write-LogEntry -Message "Starting $($MyInvocation.MyCommand.Name)" -Severity Information -Path $logPath

# Add rules to Windows Firewall
try {
  Write-LogEntry -Message "Getting logged on users profile path" -Severity Information -Path $logPath
  $userInfo = Get-UserInfo

  if ($null -eq $userInfo) {
    Write-LogEntry -Message "Failed to find users profile path" -Severity Error -Path $logPath
    Exit 3
  }
  else {
    # Found logged on users information
    Write-LogEntry -Message "Users profile path = $($userInfo.ProfilePath)" -Severity Information -Path $logPath
    $userTeamsPath = Join-Path -Path $userInfo.ProfilePath -ChildPath $teamsProgramSuffix

    # Remove any existing Microsoft Teams rules
    Remove-ProgramFirewallRule -Path $userTeamsPath

    # Add Microsoft Teams firewall rules
    Add-TeamsFirewallRule -User $userInfo.User -Path $userTeamsPath

    # Stop logging
    Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)" -Severity Information -Path $logPath
  }
}
catch [System.Exception] {
  # Something whent wrong
  Write-LogEntry -Message "Something went wrong!" -Severity Error -Path $logPath
  Write-LogEntry -Message "$($_)" -Severity Error -Path $logPath
  Exit 1
}
#endregion - Main code