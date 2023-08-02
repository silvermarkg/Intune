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
#endregion - Functions

#region - Variables
$exitCode = 0
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

    # create custom object for output
    $Output = [PSCustomObject]@{
      Service = $Item.PSChildName
      ImagePath = $Item.ImagePath
      NewImagePath = $NewImagePath
      Updated = $false
    }

    # Write updated value
    try {
      Set-ItemProperty -Path $Item.PSPath -Name ImagePath -Value $NewImagePath -Force
      $Output.Updated = $true
    }
    catch {
      # Failed to update registry value for some reason
      $exitCode = 1
    }

    # Write output
    Write-Output -InputObject $Output
  }

  # Exit
  Exit $exitCode
}
#endregion - Script