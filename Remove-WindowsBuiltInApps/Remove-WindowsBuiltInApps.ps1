<#
  .NOTES
  Author: Mark Goodman
  Twitter: @silvermakrg
  Version 1.02
  Date: 27-Jul-2022

  Release Notes
  -------------
  Based on previous scripts by vairous people. Designed for running in online mode

  Update History
  --------------
  1.02 | 27-Jul-2022 | Fixed issue with Write-LogEntry Path parameter
  1.01 | 12-Jul-2022 | Improved logging
  1.00 | 16-Jun-2022 | Initial script

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
  Remove Windows in-box AppX apps in online mode.

  .DESCRIPTION
  Removes Windows built-in apps. The list of apps are defined in the script to simplify the script and make it easy to
  deploy via Intune.

  .EXAMPLE
  Remove-WindowsBuiltInApps.ps1
	
	Description
	-----------
	Removes Windows built-in apps defined in script
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
function Write-LogEntry {
  <#
		.SYNOPSIS
		Writes a message to a log file.

		.DESCRIPTION
		Writes an infomational, warning or error meesage to a log file. Log entries can be written in basic (default) or cmtrace format.
    When using basic format, you can choose to include a date/time stamp if required.

		.PARAMETER Message
		The message to write to the log file

		.PARAMETER Severity
		The severity of message to write to the log file. This can be Information, Warning or Error. Defaults to Information.

		.PARAMETER Path
		The path to the log file.

		#.PARAMETER AddDateTime (currently not supported)
		Adds a datetime stamp to each entry in the format YYYY-MM-DD HH:mm:ss.fff

		.EXAMPLE
    Write-LogEntry -Message "Searching for file" -Severity Information -Path C:\MyLog.log 

    Description
    -----------
    Writes a basic log entry

  .EXAMPLE
    Write-LogEntry -Message "Searching for file" -Severity Warning -Path C:\MyLog.log -CMTraceFormat 

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

    [Parameter(Mandatory = $false, Position = 2, HelpMessage = "The full path of the log file that the entry will written to")]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ (Test-Path -Path $_.Substring(0, $_.LastIndexOf("\")) -PathType Container) -and (Test-Path -Path $_ -PathType Leaf -IsValid) })]
    [String]$Path = $Script:LogPath,

    [Parameter(ParameterSetName = "CMTraceFormat", HelpMessage = "Indicates to use cmtrace compatible logging")]
    [Switch]$CMTraceFormat

    <# Currently not supported - basic log entries will include datetime stamp
        [Parameter(ParameterSetName="BasicDateTime",HelpMessage="Indicated to add datetime to basic log entry")]
        [Switch]$AddDateTime
        #>
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
    # AddDateTime parameter currently not supported
    #if ($AddDateTime) {
    $LogText = "[{0} {1}][{2}] {3}" -f $Date, $Time, $Severity.PadRight(12), $Message
    #}
    #else {
    #    $LogText = "{0}: {1}" -f $Severity, $Message
    #}
  }

  # Add value to log file
  try {
    Out-File -InputObject $LogText -Append -NoClobber -Encoding Default -FilePath $Path -ErrorAction Stop
  }
  catch [System.Exception] {
    Write-Warning -Message "Unable to append log entry to file '$($Path)'. Error message: $($_.Exception.Message)"
  }
}
#endregion - Functions

#region - Main code
#-- Script variables --#
# PS v2+ = $scriptDir = split-path -path $MyInvocation.MyCommand.Path -parent
# PS v4+ = Use $PSScriptRoot for script path
$ScriptBaseName = "Remove-WindowsBuiltInApps"
$LogPath = "$($env:SystemRoot)\Temp\$($ScriptBaseName).log"

<#
TODO: Move the app list to a file on Azure storage so we don't need to keep updating the script and we can cater for different lists if needed
#>
# List based off of current list in ConfigMgr
$AppList = @(
    "Microsoft.549981C3F5F10" # Cortana
    "Microsoft.BingWeather"
    "Microsoft.GetHelp"
    "Microsoft.Getstarted"
    "Microsoft.MicrosoftOfficeHub"
    "Microsoft.MicrosoftSolitaireCollection"
    "Microsoft.People"
    "Microsoft.SkypeApp"
    "Microsoft.Wallet"
    "microsoft.windowscommunicationsapps"
    "Microsoft.Xbox.TCUI"
    "Microsoft.XboxApp"
    "Microsoft.XboxGameOverlay"
    "Microsoft.XboxGamingOverlay"
    "Microsoft.XboxIdentityProvider"
    "Microsoft.XboxSpeechToTextOverlay"
    "Microsoft.YourPhone"
    "Microsoft.ZuneMusic"
    "Microsoft.ZuneVideo"
    "Microsoft.Office.OneNote"
    "Microsoft.MixedReality.Portal"
    "Microsoft.WindowsFeedbackHub"
)

#-- Main code --#
# Start logging. Using transcript as only need simple logging
Write-LogEntry -Message ("=" * 40) -Severity Information
Write-LogEntry -Message "Starting $($ScriptBaseName)" -Severity Information

# Get installed Appx packages
$AppxPackages = Get-AppxPackage
$AppxProvisioned = Get-AppxProvisionedPackage -Online

# Remove built-in apps
foreach ($App in $AppList) {
  # Update log
  Write-LogEntry -Message "Processing $($App)" -Severity Information

  # Remove provisioned app
  $currentApp = $AppxProvisioned | Where-Object -FilterScript { $_.DisplayName -eq $App }
  if ($null -ne $currentApp) {
    # Provisioned app exists so remove
    try {
      Write-LogEntry -Message "Removing AppxProvisionedPackage $($App)" -Severity Information
      $currentApp | Remove-AppxProvisionedPackage -Online
    }
    catch [System.Exception] {
      Write-LogEntry -Message "Failed to remove AppxProvisionedPackage $($App)" -Severity Error
      Write-LogEntry -Message $_.Exception.Message -Severity Error
    }
  }
  else {
    Write-LogEntry -Message "AppxProvisionedPackage not installed" -Severity Information
  }

  # Remove AppxPackage
  $currentApp = $AppxPackages | Where-Object -FilterScript { $_.Name -eq $App }
  if ($null -ne $currentApp) {
    # AppxPackage exists so remove
    try {
      Write-LogEntry -Message "Removing AppxPackage $($App)" -Severity Information
      $currentApp | Remove-AppxPackage
    }
    catch [System.Exception] {
      Write-LogEntry -Message "Failed to remove AppxPackage $($App)" -Severity Error
      Write-LogEntry -Message $_.Exception.Message -Severity Error
    }
  }
  else {
    Write-LogEntry -Message "AppxPackage not installed" -Severity Information
  }
}

# Start logging. Using transcript as only need simple logging
Write-LogEntry -Message "Completed $($ScriptBaseName)" -Severity Information
Write-LogEntry -Message ("=" * 40) -Severity Information
#endregion - Main code
