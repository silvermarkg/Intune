# Get-UserManagedDevices

Uses the Microsoft.Graph.Intune PowerShell module to get managed devices associated with a user or group of users.
You can specify a single user by userPrincipalName or an AzureAD group by name or objectId.
You can specify the OS of the devices to return, for example only return Windows devices or iOS and Andriod devices.
You can specify device name prefixes to only return devices that match the prefixes. For example only return devices starting 
with "L" or return devices starting with "L" and "D".

Script returns device objects or you can output to CSV using the Path parameter.
