<#PSScriptInfo
.DESCRIPTION
 Remediates any unquoted service image paths.
.VERSION 1.0.0
.GUID 
.AUTHOR Mark Goodman (@silvermarkg)
.COMPANYNAME 
.COPYRIGHT 2023 Mark Goodman
.TAGS 
.LICENSEURI https://gist.github.com/silvermarkg/f58688cacdd51f9228441b8d124a6a03
.PROJECTURI 
.ICONURI 
.EXTERNALMODULEDEPENDENCIES 
.REQUIREDSCRIPTS 
.EXTERNALSCRIPTDEPENDENCIES 
.RELEASENOTES
Version 1.0.0 | 09-Feb-2023 | Initial script
#>

<#
  .SYNOPSIS
  Remidiates any unquoted service image paths.
  .DESCRIPTION
  For use as a proactive remediation script package in Intune Endpoint Analytics.
  
  This script will remediate any unquoted service image path. Any unquoted paths found will be fixed (quotes added) and 
  written to the output to indicate the service updated
#> 

#region - Script Environment
#Requires -Version 5
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
#endregion - Script Environment

#region - Functions
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

		.PARAMETER Path
		The path to the log file. Recommended to use Set-LogPath to set the path.

		#.PARAMETER AddDateTime (currently not supported)
		Adds a datetime stamp to each entry in the format YYYY-MM-DD HH:mm:ss.fff

		.EXAMPLE
    Write-LogEntry -Message "Searching for file" -Severity Information -Path C:\MyLog.log 

    Description
    -----------
    Writes a basic log entry

    .EXAMPLE
    Write-LogEntry -Message "Searching for file" -Severity Warning -LogPath C:\MyLog.log -CMTraceFormat 

    Description
    -----------
    Writes a CMTrace format log entry

		.EXAMPLE
    $Script:LogPath = "C:\MyLog.log"
    Write-LogEntry -Message "Searching for file" -Severity Information 

    Description
    -----------
    First line creates the script variable LogPath
    Second line writes to the log file.
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

    [Parameter(Mandatory = $false, Position = 2, HelpMessage = "The full path of the log file that the entry will written to")]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ (Test-Path -Path $_.Substring(0, $_.LastIndexOf("\")) -PathType Container) -and (Test-Path -Path $_ -PathType Leaf -IsValid) })]
    [String]$Path = $Script:LogPath
  )

  # Construct date and time for log entry (based on currnent culture)
  $Date = Get-Date -Format (Get-Culture).DateTimeFormat.ShortDatePattern
  $Time = Get-Date -Format (Get-Culture).DateTimeFormat.LongTimePattern.Replace("ss", "ss.fff")

  # Construct basic log entry
  $LogText = "[{0} {1}] [{2}] {3}" -f $Date, $Time, $Severity, $Message

  # Add value to log file
  try {
    Out-File -InputObject $LogText -Append -NoClobber -Encoding Default -FilePath $Path -ErrorAction Stop
  }
  catch [System.Exception] {
    Write-Warning -Message "Unable to append log entry to $($Path) file. Error message: $($_.Exception.Message)"
  }
}
#endregion - Functions

#region - Variables
$exitCode = 0
$Success = 0
$Failed = 0
$LogPath = "$($env:Temp)\ServiceImagePaths.log"
#endregion - Variables

#region - Script
# Get all service image paths that have unquoted paths
$Services = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\*" -Name ImagePath -ErrorAction SilentlyContinue | Where-Object -FilterScript {
  # Regualar expression excludes any paths that start with \??\ or do not contain spaces or are already quoted
  $_.ImagePath -match '^(?!\\\?\?\\)(?!\u0022)(.+?\s.+?(\..+?\s|\..+))(?<!\u0022)'
}

# Determine action based on detection
if ($null -eq $Services) {
  # No unqoted services found, so no remediation required
  Write-Host -Object "0 found"
  Exit 0
}
else {
  # Unqouted services found, remediate
  foreach ($Item in $Services) {
    # Get new quoted path
    $NewImagePath = $Item.ImagePath -replace '^(.+?\s.+?(\..+?(?=\s)|\..+))(.*)$', '"$1"$3'

    # Write updated value
    Write-LogEntry -Message "Updated service image path"
    Write-LogEntry -Message "  Service = $($Item.PSChildName)"
    Write-LogEntry -Message "  ImagePath = $($Item.ImagePath)"
    Write-LogEntry -Message "  NewImagePath = $($NewImagePath)"

    try {
      # Update service image path
      Set-ItemProperty -Path $Item.PSPath -Name ImagePath -Value $NewImagePath -Force
      $Success++
    }
    catch {
      # Failed to update registry value for some reason
      $exitCode = 1
      $Failed++
    }
  }

  # Write output
  Write-Host -Object "Success: $($Success); Failed: $($Failed)"

    # Exit
  Exit $exitCode
}
#endregion - Script