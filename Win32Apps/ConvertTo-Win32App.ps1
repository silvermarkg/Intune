
<#PSScriptInfo
.DESCRIPTION
 Converts source content to a Win32App using the Microsoft Win32 Content Prep Tool and allows you to specify the name of
 the output .intunewin file. 

.VERSION 1.0.3
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
Version 1.0.3 | 18-Mar-2024 | Fixed overwriting output file on rename
Version 1.0.2 | 08-Nov-2022 | Added validation on parameter paths
Version 1.0.1 | 21-Jul-2022 | Added confirmation to overwrite exising output file
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
  [ValidateScript({ Test-Path -Path $_ -PathType Container })]
  [String]$ContentPath,

  [Parameter(Mandatory = $true, Position = 1)]
  [ValidateNotNullOrEmpty()]
  [String]$SetupFile,

  [Parameter(Mandatory = $true, Position = 2)]
  [ValidateNotNullOrEmpty()]
  [ValidateScript({ Test-Path -Path $_ -PathType Container })]
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
function Confirm-OverwriteFile {
  #region - Parameters
  [Cmdletbinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [String]$Path
  )
  #endregion - Parameters

  #region - Script
  if ($PSCmdlet.ShouldProcess($Path,"Overwrite file")) {
    return $true
  }
  else {
    return $false
  }
}
#endregion - Functions

#region - Variables
$Win32ContentTool = "$($PSScriptRoot)\IntuneWinAppUtil.exe"
$setupFileFullPath = Join-Path -Path $ContentPath -ChildPath $SetupFile

#endregion - Variables
#region - Main code
# Check Win32 Content Prep tool is in same folder as script
if (Test-Path -Path $Win32ContentTool -PathType Leaf) {
  # Check setup file exists
  if (Test-Path -Path $setupFileFullPath -PathType Leaf) {
    # Package app contents
    & "$($Win32ContentTool)" -c "$($ContentPath)" -s "$($SetupFile)" -o "$($OutputPath)"

    # Check if output file exists
    $OutputFileName = Join-Path -Path $OutputPath -ChildPath ($SetupFile -replace '(\..*)$', ".intunewin")

    # Rename output file if required
    if ($null -ne $Name -and "" -ne $Name -and (Test-Path -Path $OutputFileName -PathType Leaf)) {
      # Set new file name
      $NewFileName = Join-Path -Path $OutputPath -ChildPath "$($Name).intunewin"

      # Confirm if file should be replaced if it exists
      if (Test-Path -Path $NewFileName -PathType Leaf) {
        $OverwriteFile = Confirm-OverwriteFile -Path $NewFileName
        if ($OverwriteFile) {
          # Delete existing file
          Remove-Item -Path $NewFileName -Force
        }
        else {
          # Set new name for file (add date time to avoid conflict)
          $DateString = Get-Date -Format "yyyyMMdd_HHmmss"
          $NewFileName = $NewFileName.Replace(".intunewin", "_$($DateString).intunewin")
        }
      }
      
      # Rename file
      Rename-Item -Path $OutputFileName -NewName $NewFileName
    }
  }
  else {
    Write-Warning -Message "Setup file does not exist!"
  }
}
else {
  Write-Warning -Message "Please ensure the Microsoft Win32 Content Prep Tool (IntuneWinAppUtil.exe) is located in the same folder as this script!"
}
#endregion - Main code
