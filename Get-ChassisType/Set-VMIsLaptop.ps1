<#
  .SYNOPSIS
  Marks a virtual machine as a laptop for testing purposes. This allows you to build a virtial machine with laptop only 
  configuration.

  .DESCRIPTION
  Set the registry value HKLM\Software\Testing\IsLaptop = 1 (Dword) to mark virtual machine as laptop. Use with Get-ChassisType.ps1
  to detect if laptop.
  
  .NOTES
  Author: Mark Goodman
  Twitter: @silvermakrg
  Version 1.0.0
  Date: 05-Jul-2022

  Release Notes
  -------------

  Update History
  --------------
  1.0.0 | 05-Jul-2022 | Initial script

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
$VMLaptopRegKey = "HKLM:\SOFTWARE\Testing"
#endregion Script variables

#region Main code
# Determine if virtual machine
$Model = (Get-CimInstance -ClassName Win32_ComputerSystem).Model
if ($Model -in "Virtual Machine", "VMware Virtual Platform", "VMware7,1", "VirtualBox") {
  # Virtual machine detected
  # Set virtual machine as laptop
  New-Item -Path $VMLaptopRegKey -Force | Out-Null
  Set-ItemProperty -Path $VMLaptopRegKey -Name IsLaptop -Value 1 -Type Dword -Force
}
#endregion Main code
