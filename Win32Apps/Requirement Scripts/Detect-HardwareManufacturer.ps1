<#PSScriptInfo
.DESCRIPTION
 Returns manufacture of hardware from Win32_ComputerSystem.
 Designed for use as Intune Win32 app requirement

.VERSION 1.0.0
.GUID 
.AUTHOR Mark Goodman (@silvermarkg)
.COMPANYNAME 
.COPYRIGHT 2022 Mark Goodman
.TAGS 
.LICENSEURI MIT License
.PROJECTURI 
.ICONURI 
.EXTERNALMODULEDEPENDENCIES 
.REQUIREDSCRIPTS 
.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES
Version 1.0.0 | 26-Sep-2022 | Initial script
#>

<#
  .SYNOPSIS
  Returns manufacture of hardware from Win32_ComputerSystem.

  .DESCRIPTION
  Uses Win32_ComputerSystem to return the manufacture property value.

  .EXAMPLE
  Detect-HardwareManufacture.ps1
	
	Description
	-----------
	Retuns the hardware manufacture name, for example 'Dell Inc.'
#> 

#region - Parameters
[Cmdletbinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param()
#endregion - Parameters

#region - Script Environment
#requires -Version 5
#requires -RunAsAdministrator
Set-StrictMode -Version Latest
#endregion - Script Environment

#region - Functions
#endregion - Functions

#region - Variables
#endregion - Variables

#region - Script
try {
  $Manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
}
catch [System.Exception] {
  $Manufacturer = ""
}

# return manufacturer
return $Manufacturer

#endregion - Script
