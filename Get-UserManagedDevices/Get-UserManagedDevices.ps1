
<#PSScriptInfo
.DESCRIPTION
 Get Intune managed devices associated with a user or group of users.

.VERSION 1.1.0
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
Version 1.0.0 | 14-Sep-2022 | Initial script
Version 1.1.0 | 23-Oct-2023 | Updated to use Microsoft Graph modules

#>

<#
  .SYNOPSIS
  Get Intune managed devices associated with a user or group of users.

  .DESCRIPTION
  Uses the Microsoft Graph PowerShell modules to get managed devices associated with a user or group of users.
  You can specify a single user by userPrincipalName or an AzureAD group by name or objectId.
  You can specify the OS of the devices to return, for example only return Windows devices or iOS and Android devices.
  You can specify device name prefixes to only return devices that match the prefixes. For example only return devices starting 
  with "L" or return devices starting with "L" and "D".

  Script returns device objects or you can output to CSV using the Path parameter.

  .PARAMETER Identity
  Specifies the userPrincipalName to find devices for.

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

  .PARAMETER TenantId
  Optionally specify the tenant Id to connect to.
	
  .EXAMPLE
  Get-UserManagedDevices.ps1.ps1 -Identity sjones@mydomain.com

  Description
  -----------
  Returns managed devices associated with the user sjones@mydomain.com

  .EXAMPLE
  Get-UserManagedDevices.ps1.ps1 -GroupName Sales -Path C:\SalesDevices.csv

  Description
  -----------
  Returns managed devices associated with all members of the Azure AD group 'Sales' and exports the data to a CSV file

  .EXAMPLE
  Get-UserManagedDevices.ps1.ps1 -GroupName Sales -OperatingSystem Windows

  Description
  -----------
  Returns managed Windows devices associated with all the members of the Azure AD group 'Sales'
  
  .EXAMPLE
  Get-UserManagedDevices.ps1.ps1 -GroupId '73069750-4d09-4d85-b106-3318c72732b2' -OperatingSystem iOS,Android

  Description
  -----------
  Returns managed iOS and Android devices associated with all the members of the group with objectId '73069750-4d09-4d85-b106-3318c72732b2'

  .EXAMPLE
  Get-UserManagedDevices.ps1.ps1 -GroupName Sales -DeviceNamePrefix 'L-','D-'

  Description
  -----------
  Returns managed devices associated with all the members of the 'Sales' group and only returns devices starting with 'L-' or 'D-'
#> 

#region - Parameters
[Cmdletbinding(DefaultParameterSetName = "GroupId", SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
  [Parameter(ParameterSetName = "UPN", Mandatory = $true, Position = 0, HelpMessage = "User UPN")]
  [ValidateNotNullOrEmpty()]
  [String[]]$Identity,

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
  [String]$LastSyncDate,

  [Parameter(Mandatory = $false)]
  [ValidateNotNullOrEmpty()]
  [String]$Path,

  [Parameter(Mandatory = $false)]
  [ValidateNotNullOrEmpty()]
  [String]$TenantId
)
#endregion - Parameters

#region - Script Environment
#Requires -Version 5
#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Groups, Microsoft.Graph.DeviceManagement
Set-StrictMode -Version Latest
#endregion - Script Environment

#region - Functions
function AuthenticateTo-MsGraph {
  #region - Parameters
  [Cmdletbinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  param()

  try {
    $GraphContext = Get-MgContext -ErrorAction Stop
    if ($Script:TenantId -and $GraphContext.TenantId -ne $Script:TenantId) {
      # Connected to different tenant. Disconnect and re-connect
      Disconnect-MgGraph | Out-Null
      Connect-MgGraph -TenantId $Script:TenantId | Out-Null
    }
    else {
      throw "Not connected!"
    }
  }
  catch [System.Exception] {
    # Authenticate
    Connect-MgGraph | Out-Null
  }
}

function Get-AllGroupMembers {
  <#
		.SYNOPSIS
		Gets all members users or devices of an Entra group including memebers of nested groups.

		.DESCRIPTION
		
		.PARAMETER GroupId
		The Entra group Id of the group to query.
  #>

  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [String]$GroupId, 

    [Parameter(Mandatory = $true, Position = 1)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet("User", "Device")]
    [String]$Type
  )

  # Declare variables
  $Members = @()

  # Get members of group
  switch ($Type) {
    "User" { $Members += Get-MgGroupMemberAsUser -GroupId $GroupId -All }
    "Device" { $Members += Get-MgGroupMemberAsDevice -GroupId $GroupId -All }
  }

  # Get nested group members
  $NestedGroups = Get-MgGroupMemberAsGroup -GroupId $GroupId -All

  # Enumerate direct members
  foreach ($Group in $NestedGroups) {
    $Members += Get-AllGroupMembers -GroupId $Group.Id -Type $Type
    ## Might need to enumerate the nested group members to remove/avoid duplicates
    ## or see if there is another way to remove them afterwards
  }

  # Filter out duplicates
  $Members = $Members | Select-Object -Property * -Unique

  # Return members
  return $Members
}
#endregion - Functions

#region - Variables
$ScriptBaseName = (Get-ChildItem -Path $PSCommandPath).BaseName
$devices = @()
#endregion - Variables

#region - Process

# Connect to MSGraph
AuthenticateTo-MsGraph

if ($PSCmdLet.ParameterSetName -eq "UPN") {
  # Get devices for users
  $Members = @()
  foreach ($upn in $Identity) {
    # Get devices for specific users
    $Members += [PSCustomObject]@{
      userPrincipalName = $upn
    }
  }
}
elseif ($PSCmdLet.ParameterSetName -eq "GroupName") {
  $Group = Get-MgGroup -Filter "displayName eq '$($GroupName)'"
  if ($Group) {
    $Members = Get-AllGroupMembers -GroupId $Group.Id -Type User
  }
}
else {
  # Get group members by group id
  $Members = Get-AllGroupMembers -GroupId $GroupId -Type User
}

# Define Operating System filter
$osFilter = ""
if ($PSBoundParameters.ContainsKey("OperatingSystem")) {
  $osFilter += " and ("
  for ($i=0; $i -lt $OperatingSystem.Length; $i++) {
    if ($i -eq 0) {
      $osFilter += "operatingSystem eq '$($OperatingSystem[$i])'"
    }
    else {
      $osFilter += "or operatingSystem eq '$($OperatingSystem[$i])'"
    }
  }
  $osFilter += ")"
}

# Define last sync date filter
$lastSyncFilter = ""
if ($PSBoundParameters.ContainsKey("LastSyncDate")) {
  $lastSyncFilter += " and (lastSyncDateTime ge $($LastSyncDate))"
}

# Get devices for all members
Write-Verbose -Message "Members found: $($Members.Count)"
foreach ($User in $Members) {
  $devices += Get-MgDeviceManagementManagedDevice -Filter "userPrincipalName eq '$($User.userPrincipalName)' $($osFilter) $($lastSyncFilter)" -All
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