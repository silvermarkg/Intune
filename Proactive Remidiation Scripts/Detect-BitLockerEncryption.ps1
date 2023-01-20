#region - Process
try {
  # Get BitLocker volume info
  $bdeStatus = Get-BitLockerVolume -MountPoint $env:SystemDrive

  # Define volume status enums (must be done after call to Get-BitLocker)
  $volumeStatus = @(
    [Microsoft.BitLocker.Structures.BitLockerVolumeStatus]::FullyEncrypted
    [Microsoft.BitLocker.Structures.BitLockerVolumeStatus]::EncryptionInProgress
  )

  # Write status to output
  $outputString = $bdeStatus.VolumeStatus

  # Determine result - FullyEncrypted or EncryptionInProgress is success, anything else is failure
  if ($bdeStatus.VolumeStatus -in $volumeStatus) {
    # BitLocker is encrypted or encrypting
    $resultCode = 0
  }
  else {
    $resultCode = 1
  }
}
catch [System.Exception] {
  # Could not get BitLocker status so set to unknown
  $outputString = "Unknown"
  $resultCode = 1
}

# Return result
Write-Output -InputObject $outputString
exit $resultCode
#endregion - Process
