<#PSScriptInfo
.DESCRIPTION
 Detects if Microsoft 365 Apps (C2R) is installed
 Designed for use as Intune Win32 app requirement or Proactive Remediation

.VERSION 1.0.0
.GUID 
.AUTHOR Mark Goodman (@silvermarkg)
.COMPANYNAME 
.COPYRIGHT 2023 Mark Goodman
.TAGS 
.LICENSEURI https://gist.githubusercontent.com/silvermarkg/f58688cacdd51f9228441b8d124a6a03/raw/6fa8cd4c4074b7415c3b1e09243e1ac64145b80e/mit-license.txt
.PROJECTURI 
.ICONURI 
.EXTERNALMODULEDEPENDENCIES 
.REQUIREDSCRIPTS 
.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES
Version 1.0.0 | 13-Jan-2023 | Initial script
#>

<#
  .SYNOPSIS
  Detects if Microsoft 365 Apps (C2R) is installed

  .DESCRIPTION
  Checks if HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Office\ClickToRun\Configuration\ProductReleaseIds contains O365ProPlusRetail
#> 

#region - Parameters
[Cmdletbinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param()
#endregion - Parameters

#region - Script Environment
#requires -Version 5
# requires -RunAsAdministrator
Set-StrictMode -Version Latest
#endregion - Script Environment

#region - Functions
#endregion - Functions

#region - Variables
$Path = "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration"
$Name = "ProductReleaseIds"
$Product = "O365ProPlusRetail"
$IsInstalled = $false
#endregion - Variables

#region - Script
# Determine if M365 apps is installed
if (Test-Path -Path $Path -PathType Container) {
  try {
    $Value = Get-ItemPropertyValue -Path $Path -Name $Name
    if ($Value.Contains($Product)) {
      $IsInstalled = $true
    }
  }
  catch {
    # $IsInstalled defaults to not installed
  }
}

# Return result
return $IsInstalled
#endregion - Script
