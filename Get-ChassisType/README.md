# Get-ChassisType

**Get-ChassisType.ps1**
Determines the device type (laptop, desktop or VDI) from the ChassisTypes property of the Win32_SystemEnclosure class.
Useful as script requirement for Win32Apps in Intune.

Returns string value of 'IsLaptop', 'IsDesktop' or 'IsVDI'

If a virtual machine, it checks if it's been marked as laptop for testing purposed. To mark a virtual machine as a laptop,
use the `Set--VMIsLaptop.ps1`.

**Set-VMIsLaptop.ps1**
Marks a virtual machine as a laptop for testing purposes. This allows you to build a virtial machine with laptop only 
configuration.
Use `Get-ChassisType.ps1` to detect if laptop.
