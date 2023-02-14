<#
.SYNOPSIS
Convert an Azure AD Object ID to SID
From Oliver Kieselbach (https://oliverkieselbach.com/2020/05/13/powershell-helpers-to-convert-azure-ad-object-ids-and-sids/)
  
.DESCRIPTION
Converts an Azure AD Object ID to a SID.
Author: Oliver Kieselbach (oliverkieselbach.com)
The script is provided "AS IS" with no warranties.
 
.PARAMETER ObjectID
The Object ID to convert
#>

param([String] $ObjectId)

$bytes = [Guid]::Parse($ObjectId).ToByteArray()
$array = New-Object 'UInt32[]' 4

[Buffer]::BlockCopy($bytes, 0, $array, 0, 16)
$sid = "S-1-12-1-$array".Replace(' ', '-')

return $sid

