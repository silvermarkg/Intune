<#
  .SYNOPSIS
  Determines the chassis type (laptop, desktop or VDI) from the ChassisTypes property of the Win32_SystemEnclosure class.
  If a virtual machines, it checks if it's been marked as laptop for testing purposes.

  .DESCRIPTION
  Determines the chassis type (laptop, desktop or VDI) from the ChassisTypes property of the Win32_SystemEnclosure class.
  Returns string value of 'IsLaptop', 'IsDesktop' or 'IsVDI'
  This is based on code from ZTIGather.wsf from the Microsoft Deployment Toolkit.
  If a virtual machines, it checks if it's been marked as laptop for testing purposed. To mark a virtual machine
  as a laptop use Set-VMIsLaptop.ps1 or set the registry value HKLM\Software\Testing\IsLaptop = 1 (Dword) before running this script.
  
  .NOTES
  Author: Mark Goodman
  Twitter: @silvermakrg
  Version 1.00
  Date: 01-Jul-2022

  Release Notes
  -------------

  Update History
  --------------
  1.00 | 01-Jul-2022 | Initial script

  License
  -------
  MIT LICENSE
  
  Copyright (c) 2022 Mark Goodman (@silvermarkg)

  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation 
  files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, 
  modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the 
  Software is furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the 
  Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE 
  WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR 
  COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, 
  ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#>

#region - Parameters
[Cmdletbinding(SupportsShouldProcess=$true,ConfirmImpact='Low')]
param()
#endregion - Parameters

#region - Script Environment
#Requires -Version 5
# #Requires -RunAsAdministrator
Set-StrictMode -Version Latest
#endregion - Script Environment

#region - Functions
#endregion - Functions

#region Script variables
$ChassisType = $null
$VMLaptopRegKey = "HKLM:\SOFTWARE\Testing"
#endregion Script variables

#region Main code
# Determine chassis type from Win32_SystemEnclosure ChassisTypes
$SystemEnclosureInstances = Get-CimInstance -ClassName Win32_SystemEnclosure
foreach ($Instance in $SystemEnclosureInstances) {
  if ($Instance.ChassisTypes[0] -in "8", "9", "10", "11", "12", "14", "18", "21", "30", "31", "32") {
    $ChassisType = "IsLaptop"
  }
  elseif ($Instance.ChassisTypes[0] -in "3", "4", "5", "6", "7", "15", "16") {
    $ChassisType = "IsDesktop"
  }
  elseif ($Instance.ChassisTypes[0] -eq "1") {
    $ChassisType = "IsVDI"
  }
}

# Determine if VM and marked as laptop for testing purposes
$Model = (Get-CimInstance -ClassName Win32_ComputerSystem).Model
if ($Model -in "Virtual Machine", "VMware Virtual Platform", "VMware7,1", "VirtualBox") {
  # Virtual machine detected, check if marked as laptop for testing purposes
  $VMIsLaptop = Get-ItemProperty -Path $VMLaptopRegKey -Name IsLaptop -ErrorAction SilentlyContinue
  if ($null -ne $VMIsLaptop -and $VMIsLaptop.IsLaptop -eq 1) {
    $ChassisType = "IsLaptop"
  }
}

# Return result
return $ChassisType
#endregion Main code
