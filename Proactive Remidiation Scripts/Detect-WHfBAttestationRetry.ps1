<#
Detects the value of HKCU\Software\Microsoft\Windows NT\CurrentVersion\WorkplaceJoin\AADNGC\NumOfAttRetry to determine if there is an issue with
Windows Hello for Business.
#>
#region - Process
# Get value of NumOfAttRetry
$NumOfAttRetry = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\WorkplaceJoin\AADNGC" -Name NumOfAttRetry -ErrorAction SilentlyContinue

# Determine if we need to remediate
if ($null -ne $NumOfAttRetry -and $NumOfAttRetry -ne 0) {
  # Remediation required
  Write-Host -Object $NumOfAttRetry
  Exit 1
}
else {
  Write-host "A"
  Exit 0
}
Write-Host "B"
#endregion - Process
