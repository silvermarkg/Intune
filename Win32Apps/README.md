# Win32Apps
Collection of PowerShell scripts applicable to Win32Apps in Microsoft Endpoint Manager.

**ConvertTo-Win32App** 
Creates a Win32App package from source contents and allows naming of the .intunewin file. 
The [Microsoft Win32 Content Prep Tool](https://github.com/Microsoft/Microsoft-Win32-Content-Prep-Tool) must reside in the same folder as the script.

**SetBitLockerPin** 
Prompts standard user to set a BitLocker pre-boot PIN. 
Based on Oliver Kieselbach (oliverkieselbach.com) solution, however instead of prompting during install of Win32App, 
this installs a scheduled task to ensure the user is nagged constantly to set the PIN.
