
<#PSScriptInfo
.DESCRIPTION
 Converts source content to a Win32App using the Microsoft Win32 Content Prep Tool and allows you to specify the name of
 the output .intunewin file. 

.VERSION 1.0.0
.GUID 
.AUTHOR Mark Goodman (@silvermarkg)
.COMPANYNAME 
.COPYRIGHT 2022 Mark Goodman
.TAGS 
.LICENSEURI **Need to point this to MIT license hosted on GitHub - see https://github.com/mit-license/mit-license.github.io**
.PROJECTURI 
.ICONURI 
.EXTERNALMODULEDEPENDENCIES 
.REQUIREDSCRIPTS 
.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES
Version 1.0.0 | 06-Jul-2022 | Initial script

#>

<#
  .SYNOPSIS
  Converts source content to a Win32App using the Microsoft Win32 Content Prep Tool and allows you to specify the name of
  the output .intunewin file. 

  .DESCRIPTION
  Converts source content to a Win32App using the Microsoft Win32 Content Prep Tool and allows you to specify the name of
  the output .intunewin file. 

  .PARAMETER ContentPath
  Specifies the path containing the content to package.

  .PARAMETER SetupFile
  Specifies the main setup file that performs the installation of the app.

  .PARAMETER OutputPath
  Specifies the output path to create the .intunewin file in.
	
  .PARAMETER Name
  Specifies the name of the .intunewin output file.

  .EXAMPLE
  ConvertTo-Win32App.ps1 -ContentPath C:\Win32Apps\MyApp -SetupFile Install.exe -OutputPath C:\Win32Apps
	
	Description
	-----------
	Creates a Win32 app package (.intunewin) from the contents in C:\Win32Apps\MyApp as C:\Win32Apps\install.intunewin

  .EXAMPLE
  ConvertTo-Win32App.ps1 -c C:\Win32Apps\MyApp -s Install.exe -o C:\Win32Apps
	
	Description
	-----------
	Creates a Win32 app package (.intunewin) using the short name for parameters to match the IntuneWinAppUtil.exe switches

  .EXAMPLE
  ConvertTo-Win32App.ps1 -c C:\Win32Apps\MyApp -s Install.exe -o C:\Win32Apps -n MyApp
	
	Description
	-----------
	Creates a Win32 app package (.intunewin) from the contents in C:\Win32Apps\MyApp as C:\Win32Apps\MyApp.intunewin
#> 

#region - Parameters
[Cmdletbinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [ValidateNotNullOrEmpty()]
  [String]$ContentPath,

  [Parameter(Mandatory = $true, Position = 1)]
  [ValidateNotNullOrEmpty()]
  [String]$SetupFile,

  [Parameter(Mandatory = $true, Position = 2)]
  [ValidateNotNullOrEmpty()]
  [String]$OutputPath,

  [Parameter(Mandatory = $false, Position = 3)]
  [String]$Name
)
#endregion - Parameters

#region - Script Environment
#Requires -Version 5
# #Requires -RunAsAdministrator
Set-StrictMode -Version Latest
#endregion - Script Environment

#region - Functions
#endregion - Functions

#region - Variables
$Win32ContentTool = "$($PSScriptRoot)\IntuneWinAppUtil.exe"

#endregion - Variables
#region - Main code
# Check Win32 Content Prep tool is in same folder as script
if (Test-Path -Path $Win32ContentTool -PathType Leaf) {
  # Package app contents
  & "$($Win32ContentTool)" -c "$($ContentPath)" -s "$($SetupFile)" -o "$($OutputPath)"

  # Rename output file
  if ($null -ne $Name -and "" -ne $Name) {
    $IntunewinFileName = (Get-Item -Path "$($ContentPath)\$($SetupFile)").BaseName + ".intunewin"
    Rename-Item -Path "$($OutputPath)\$($IntunewinFileName)" -NewName "$($Name).intunewin"
  }
}
else {
  Write-Warning -Message "Please ensure the Microsoft Win32 Content Prep Tool (IntuneWinAppUtil.exe) is located in the same folder as this script!"
}
#endregion - Main code
