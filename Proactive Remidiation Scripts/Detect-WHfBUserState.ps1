<#
Detects the value of HKCU\Software\Microsoft\Windows NT\CurrentVersion\WorkplaceJoin\AADNGC\NumOfAttRetry to determine if there is an issue with
Windows Hello for Business.
#>

#region - Functions
function Get-WHfBEnabledState {
  try {
    $WhfbEnabled = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\PassportForWork" -Name Enabled -ErrorAction Stop
  }
  catch {
    $WhfbEnabled = 0
  }

  # return result
  return $WhfbEnabled
}

function Get-WHfBUserState {
  # Check if WHfB has already been set for the user
  $UserSid = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
  $NgcPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\Credential Providers\{D6886603-9D2F-4EB2-B667-1971041FA96B}\$($UserSid)"

  # Check is Ngc is available for user (i.e. WHfB has been set up)
  try {
    $NgcAvailable = Get-ItemPropertyValue -Path $NgcPath -Name LogonCredsAvailable -ErrorAction Stop
  }
  catch {
    $NgcAvailable = 2
  }

  # return result
  return $NgcAvailable
}

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
$output = "State unknown"
$exitCode = 0

# Get WHfB information
$WHfBEnabledState = Get-WHfBEnabledState
$WHfBUserState = Get-WHfBUserState

# Validate information
if ($WHfBUserState -eq 1) {
  # User registered for WHfB
  $output = "User registered"
}
elseif ($WHfBEnabledState -eq 0) {
  # WHfB not enabled
  $output = "Device not enabled"
}
else {
  # Issue detected
  $exitCode = 1

  # WHfB is enabled, but user not registered
  $output = "User not registered"

  # Check NumOfAttRetry
  $NumOfAttRetry = Get-NumOfAttRetry
  if ($NumOfAttRetry -gt 0) {
    # Potential auto-prompt issue
    $output += " (NumOfAttRetry: $($NumOfAttRetry))"
  }
}
# Write output
Write-Host -Object $output
Exit $exitCode
