# Define script variables
$PackageId = "<Package.Id>" # Update <Package.Id> with id for app
$CurrentVersion = $null
$AvailableVersion = $null

# Search for installed WinGet package
$WinGetResponse = winget list --id $PackageId --count 1 --source winget
if ($null -ne $WinGetResponse) {
  # Package found, determine versions
  $WinGetLine = $WinGetResponse | Select-String $PackageId -SimpleMatch
  if ($WinGetLine -match "$($PackageId) (.*)? (.*)? ") {
    # Store version information
    $CurrentVersion = [Version]$Matches[1]
    $AvailableVersion = [Version]$Matches[2]

    # Check if newer version available
    if ($CurrentVersion -ge $AvailableVersion) {
      # Package up to date
      Write-Host -Object "WinGet package detected"
      Exit 0
    }
    else {
      # Package needs updating
      Exit 1
    }
  }
  else {
    # Failed to determine WinGet package version
    Exit 1
  }
}
else {
  # Package not found. Not a WinGet package
  Exit 1
}