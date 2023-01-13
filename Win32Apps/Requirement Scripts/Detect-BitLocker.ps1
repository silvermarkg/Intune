<#PSScriptInfo
.DESCRIPTION
 Detects if BitLocker encryption is enabled for the system drive.
 Designed for use as Intune Win32 app requirement or Proactive Remediation

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
Version 1.0.0 | 05-Jul-2022 | Initial script
#>

<#
  .SYNOPSIS
  Detects if BitLocker encryption is enabled for the system drive.

  .DESCRIPTION
  Uses Win32_EncryptableVolume to determine if encryption is enabled on system drive.
  Encryption is deemed to be enabled if the following is true
  
  1. ConversionStatus = 1 and ProtectionStatus = 1 (FullyEncrypted and protection ON)
  2. ConversionStatus = 2 and ProtectionStatus = 0 (EncryptionInProgress and protection OFF)

  ConversionStatus values - https://docs.microsoft.com/en-us/windows/win32/secprov/getconversionstatus-win32-encryptablevolume
  ProtectionStatus values - https://docs.microsoft.com/en-us/windows/win32/secprov/getprotectionstatus-win32-encryptablevolume

  .PARAMETER ParamName
  <parameter description>
	
  .EXAMPLE
  <ScriptName>.ps1
	
	Description
	-----------
	<example description>
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
$encrypted = $false
#endregion - Variables

#region - Script
$SystemDriveBDEStatus = Get-CimInstance -Namespace root\cimv2\Security\MicrosoftVolumeEncryption -Query "Select * From Win32_EncryptableVolume Where DriveLetter = '$($env:SystemDrive)'" -ErrorAction SilentlyContinue
if ($null -ne $SystemDriveBDEStatus) {
  # Determine encrypted status
  if ($SystemDriveBDEStatus.ConversionStatus -eq 1 -and $SystemDriveBDEStatus.ProtectionStatus -eq 1) {
    # FullyEncrypted and Protection ON
    $encrypted = $true
  }
  elseif ($SystemDriveBDEStatus.ConversionStatus -eq 2 -and $SystemDriveBDEStatus.ProtectionStatus -eq 0) {
    # EncryptionInProgress and Protection OFF
    $encrypted = $true
  }
}

# Return result
return $encrypted

#endregion - Script
