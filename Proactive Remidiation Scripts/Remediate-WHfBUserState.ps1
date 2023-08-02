<#
Removes the value HKCU\Software\Microsoft\Windows NT\CurrentVersion\WorkplaceJoin\AADNGC\NumOfAttRetry to allow Windows Hello for Business to prompt user.
#>

<#
Detects the value of HKCU\Software\Microsoft\Windows NT\CurrentVersion\WorkplaceJoin\AADNGC\NumOfAttRetry to determine if there is an issue with
Windows Hello for Business.
#>

#region - Functions
function Get-NumOfAttRetry {
  try {
    $NumOfAttRetry = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\WorkplaceJoin\AADNGC" -Name NumOfAttRetry -ErrorAction Stop
  }
  catch {
    $NumOfAttRetry = -1
  }

  # return result
  return $NumOfAttRetry
}
#endregion - Functions

#region - Process
$output = "User not registered"
$exitCode = 0

# Check NumOfAttRetry
$NumOfAttRetry = Get-NumOfAttRetry
if ($NumOfAttRetry -gt 0) {
  # Potential auto-prompt issue, remove value
  try {
    # Remove registry value
    Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\WorkplaceJoin\AADNGC" -Name NumOfAttRetry -ErrorAction Stop
    $output += " (NumOfAttRetry value removed)"
  }
  catch [System.Exception] {
    # Failed to remove registry value - remediation failed
    $output += " (Failed to remove NumOfAttRetry value)"
    $exitCode = 1
  }
}
elseif ($NumOfAttRetry -eq -1) {
  # NumofAttRetry does not exist so likely previously removed
  $output += " (NumOfAttRetry does not exist)"
}

# Write output
Write-Host -Object $output
Exit $exitCode
#endregion - Process
