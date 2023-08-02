<#
Removes the value HKCU\Software\Microsoft\Windows NT\CurrentVersion\WorkplaceJoin\AADNGC\NumOfAttRetry to allow Windows Hello for Business to prompt user.
#>
#region - Process
# Attempt to remove registry value
try {
  # Remove registry value
  Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\WorkplaceJoin\AADNGC" -Name NumOfAttRetry -ErrorAction Stop
  Write-Host -Object "Success"
  Exit 0
}
catch [System.Exception] {
  # Failed to remove registry value - remediation failed
  Write-Host -Object "Failed"
  Exit 1
}
#endregion - Process
