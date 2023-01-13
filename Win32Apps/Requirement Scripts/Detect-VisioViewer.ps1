<#PSScriptInfo
.DESCRIPTION
 Detects if Visio Viewer is installed
 Designed for use as Intune Win32 app requirement or Proactive Remediation

.VERSION 1.0.0
.GUID 
.AUTHOR Mark Goodman (@silvermarkg)
.COMPANYNAME 
.COPYRIGHT 2022 Mark Goodman
.TAGS 
.LICENSEURI https://gist.githubusercontent.com/silvermarkg/f58688cacdd51f9228441b8d124a6a03/raw/6fa8cd4c4074b7415c3b1e09243e1ac64145b80e/mit-license.txt
.PROJECTURI 
.ICONURI 
.EXTERNALMODULEDEPENDENCIES 
.REQUIREDSCRIPTS 
.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES
Version 1.0.0 | 21-Jul-2022 | Initial script
#>

<#
  .SYNOPSIS
  Detects if Visio Viewer is installed

  .DESCRIPTION
  Looks for VViewer.dll either installed with M365 Apps or Visio Viewer 2016 application.
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
$M365VisioViewerPath = "${env:ProgramFiles}\Microsoft Office\root\Office16\vviewer.dll"
$VisioViewer2016Path = "${env:ProgramFiles}\Microsoft Office\Office16\vviewer.dll"
$VisioViewerInstalled = $false
$MSEdgeInstalled = $false
#endregion - Variables

#region - Script
# Determine if Visio Viewer is installed
if ((Test-Path -Path $M365VisioViewerPath -PathType Leaf) -or (Test-Path -Path $VisioViewer2016Path -PathType Leaf)) {
  return $true
}
else {
  return $false
}
#endregion - Script
