<#PSScriptInfo
.DESCRIPTION
 Detects any unquoted service image paths.
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
  Detects any unquoted service image paths.
  .DESCRIPTION
  For use as a proactive remediation script package in Intune Endpoint Analytics.
  
  This script will detect any unquoted service image path. Any unquoted paths found will be written to the output
  and the return code will indicate remediation is required.
#> 

#region - Script Environment
#Requires -Version 5
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
#endregion - Script Environment

#region - Functions
#endregion - Functions

#region - Variables
#endregion - Variables

#region - Script
# Get all service image paths that have unquoted paths
$Services = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\*" -Name ImagePath -ErrorAction SilentlyContinue | Where-Object -FilterScript {
  # Regualar expression excludes any paths that start with \??\ or do not contain spaces or are already quoted
  # \u0022 = "
  $_.ImagePath -match '^(?!\\\?\?\\)(?!\u0022)(.+?\s.+?(\..+?\s|\..+))(?<!\u0022)'
}

# Determine action based on detection
if ($null -eq $Services) {
  # No unqoted services found, so no remediation required
  Write-Host -Object "0 found"
  Exit 0
}
else {
  # Unqouted services found
  Write-Host -Object "Services needing remediation: $(($Services | Measure-Object).Count)"

  # Causes remediation script to run
  Exit 1
}

# Example paths
<#
$a = @()
$a+= [PSCustomObject]@{Name="1"; ImagePath='"c:\program files\my app\my file.dll" -param1 -param2 param3'}
$a += [PSCustomObject]@{Name = "2"; ImagePath = 'c:\program files\my app\my file.dll -param1 -param2 param3'}
$a += [PSCustomObject]@{Name = "3"; ImagePath = 'c:\program files\anapp\my file.exe -param1 -param2 param3' }
$a += [PSCustomObject]@{Name = "4"; ImagePath = 'c:\windows\system32\file.exe'}
$a += [PSCustomObject]@{Name = "5"; ImagePath = 'c:\windows\system32\file.exe -p1 p2 "-p3"'}
$a += [PSCustomObject]@{Name = "6"; ImagePath = '\??\C:\windows\system 32\myapp.exe'}

$a | % { if ($_ -match "^(?!\u0022)(.*\s.*\..+?)(?<!\u0022)\s") { $_; $Matches}}
#>
#endregion - Script