
<#PSScriptInfo
.DESCRIPTION
 Description

.VERSION 1.0.0
.GUID 
.AUTHOR Mark Goodman (@silvermarkg)
.COMPANYNAME 
.COPYRIGHT 2022 Mark Goodman
.TAGS 
.LICENSEURI https://gist.github.com/silvermarkg/f58688cacdd51f9228441b8d124a6a03
.PROJECTURI 
.ICONURI 
.EXTERNALMODULEDEPENDENCIES 
.REQUIREDSCRIPTS 
.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES
Version 1.0.0 | 05-Jul-2022 | Initial script

#>

<#
  .SYNOPSIS
  <Short description>

  .DESCRIPTION
  <Long description>

  .PARAMETER Identity
  Specifies the userPrinciaplName to find devices for.

  .PARAMETER GroupName
  Specifies an Azure AD group name to find devices for all members.

  .PARAMETER GroupId
  Specifies an Azure AD group objectId to find devices for all members.

  .PARAMETER OperatingSystem
  Specifies the operating system of devices that should be returned. Only devices matching the operating
  system will be returned.

  .PARAMETER DeviceNamePrefix
  Specifies the device name prefixes that should be returned. Only devices matching these prefixes 
  will be returned.

  .PARAMETER Path
  Specifies the path of the csv file to export returned data to. If not specified, data is returned as 
  PowerShell objects.
	
  .EXAMPLE
  Get-UserDevices.ps1

  Description
  -----------
  <example description>
#> 

#region - Parameters
[Cmdletbinding(DefaultParameterSetName = "GroupId", SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
  [Parameter(ParameterSetName = "UPN", Mandatory = $true, Position = 0, HelpMessage = "User UPN")]
  [ValidateNotNullOrEmpty()]
  [String]$Identity,

  [Parameter(ParameterSetName = "GroupName", Mandatory = $true, Position = 0, HelpMessage = "User UPN")]
  [ValidateNotNullOrEmpty()]
  [String]$GroupName,

  [Parameter(ParameterSetName = "GroupId", Mandatory = $true, Position = 0, HelpMessage = "User UPN")]
  [ValidateNotNullOrEmpty()]
  [String]$GroupId,

  [Parameter(Mandatory = $false)]
  [ValidateNotNullOrEmpty()]
  [ValidateSet("Windows","macOS","iOS","iPadOS","Android")]
  [String[]]$OperatingSystem,

  [Parameter(Mandatory = $false)]
  [ValidateNotNullOrEmpty()]
  [String[]]$DeviceNamePrefix,

  [Parameter(Mandatory = $false)]
  [ValidateNotNullOrEmpty()]
  [String]$Path
)
#endregion - Parameters

#region - Script Environment
#Requires -Version 5
# #Requires -RunAsAdministrator
Set-StrictMode -Version Latest
#endregion - Script Environment

#region - Functions
function AuthenticateTo-MsGraph {
  #region - Parameters
  [Cmdletbinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  param()

  try {
    Get-Organization -ErrorAction Stop | Out-Null
  }
  catch [System.Exception] {
    # Authenticate
    Connect-MSGraph -ForceInteractive
  }
}
#endregion - Functions

#region - Variables
$ScriptBaseName = (Get-ChildItem -Path $PSCommandPath).BaseName
$devices = @()
#endregion - Variables

#region - Process

# Import module
Import-Module -Name Microsoft.Graph.Intune

# Connect to MSGraph
AuthenticateTo-MsGraph

# Get 
if ($Identity) {
  # Get device for specific user
  $Members = [PSCustomObject]@{
    userPrincipalName = $Identity
  }
}
elseif ($GroupName) {
  $Group = Get-Groups -Filter "displayName eq '$($GroupName)'"
  if ($Group) {
    $Members = Get-Groups_Members -groupId $Group.Id
  }
}
else {
  # Get group members by group id
  $Members = Get-Groups_Members -groupId $GroupId
}

# Define Operating System filter
$osFilter = ""
if ($PSBoundParameters.ContainsKey("OperatingSystem")) {
  $osFilter += "("
  for ($i=0; $i -lt $OperatingSystem.Length; $i++) {
    if ($i -eq 0) {
      $osFilter += "operatingSystem eq '$($OperatingSystem[$i])'"
    }
    else {
      $osFilter += "or operatingSystem eq '$($OperatingSystem[$i])'"
    }
  }
  $osFilter += ") and "
}

# Get devices for all members
foreach ($User in $Members) {
  $devices += Get-DeviceManagement_ManagedDevices -Filter "$($osFilter) userPrincipalName eq '$($User.userPrincipalName)'" | Get-MsGraphAllPages
}

# Filter on device name if required
<#
  Can do this with a Where-Object -FitlerScrpt {$_.deviceName.startsWith("LT") -or $_.deviceName.startsWith("DT")} but not sure 
  how to build the filter script from the array parameter.

  Using startsWith in the graph filter does not work when using the same property. Not sure why!

  For now, filtering using foreach
#>
if ($PSBoundParameters.ContainsKey("DeviceNamePrefix")) {
  $filteredDevices = $devices | ForEach-Object -Process {
    foreach ($prefix in $DeviceNamePrefix) {
      if ($_.deviceName.startsWith($prefix)) {
        # Device match, return
        $_
      }
    }
  }

  $devices = $filteredDevices
}

# Return results
if ($Path) {
  $devices | Export-Csv -Path $Path -NoTypeInformation
}
else {
  return $devices
}

#endregion - Process