function Convert-AzureADSidToObjectId {
<#
.SYNOPSIS
Convert a SID to its Azure AD Object ID
From Oliver Kieselbach (https://oliverkieselbach.com/2020/05/13/powershell-helpers-to-convert-azure-ad-object-ids-and-sids/)
 
.DESCRIPTION
Converts an Azure AD SID to Object ID.
Author: Oliver Kieselbach (oliverkieselbach.com)
The script is provided "AS IS" with no warranties.
 
.PARAMETER ObjectID
The SID to convert
#>

    param([String] $Sid)

    $text = $sid.Replace('S-1-12-1-', '')
    $array = [UInt32[]]$text.Split('-')

    $bytes = New-Object 'Byte[]' 16
    [Buffer]::BlockCopy($array, 0, $bytes, 0, 16)
    [Guid]$guid = $bytes

    return $guid
}
