# Author: Oliver Kieselbach (oliverkieselbach.com)
# Date: 08/01/2019
# Description: Starts the Windows Forms Dialog for BitLocker PIN entry and receives the PIN via exit code to set the additional key protector
# - 10/21/2019 changed PIN handover
# - 02/10/2020 added content length check
# - 09/30/2021 changed PIN handover to AES encryption/decryption via DPAPI and shared key
#              added simple PIN check for incrementing and decrementing numbers e.g. 123456 and 654321
#              language support (see language.json), default is always en-US
#              changed temp storage location and temp file name
# - 07/01/2022 Mark Goodman (@silvermarkg): Added fix for Popup.ps1 path with spaces in on ServiceUI command line
# - 07/06/2022 Mark Goodman (@silvermarkg): Moved adding TpmPin protector to Popup.ps1 script.
#              Deals with issue when this script terminates and no need to pass PIN via encrypted file
# - 08/08/2022 Mark Goodman (@silvermarkg): Moved logging from transcript to basic log file
#              Added logging for when user cancels prompt

#region - Functions
function Get-BitLockerStatus {
  [Cmdletbinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  param()

  #region - Variables
  $encrypted = $false
  #endregion - Variables

  #region - Process
  $SystemDriveBDEStatus = Get-CimInstance -Namespace root\cimv2\Security\MicrosoftVolumeEncryption -Query "Select * From Win32_EncryptableVolume Where DriveLetter = '$($env:SystemDrive)'" -ErrorAction SilentlyContinue
  if ($null -ne $SystemDriveBDEStatus) {
    # Determine encrypted status
    if ($SystemDriveBDEStatus.ConversionStatus -eq 1 -and $SystemDriveBDEStatus.ProtectionStatus -eq 1) {
      # FullyEncrypted and Protection ON
      $encrypted = $true
    }
    elseif ($SystemDriveBDEStatus.ConversionStatus -eq 2 -and $SystemDriveBDEStatus.ProtectionStatus -eq 0) {
      # EncryptionInProgress and Protection OFF
      $encrypted = $true
    }
  }

  # Return result
  return $encrypted
  #endregion - Process
}

function Write-BasicLog {
  param(
    [Parameter(Mandatory=$true, Position=0)]
    [ValidateNotNullOrEmpty()]
    [String]$Message,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [String]$Path = $script:LogPath
  )

  # Write to log file
  "[{0}] {1}" -f (Get-Date -Format "dd/MM/yyyy HH:mm:ss.fff"), $Message | Out-File -FilePath $Path -Append -NoClobber
}
#endregion - Functions


#region Script variables
$BdePinTask = "Set-BitLocker-PIN"
$LogPath = "$($PSScriptRoot)\SetBitLockerPin.log"

# The script is provided "AS IS" with no warranties.
Write-BasicLog -Message ("*" * 40)
Write-BasicLog -Message "Starting Set BitLocker PIN"

# Check if TpmPin protector is already set
if ((Get-BitLockerVolume -MountPoint $env:SystemDrive).KeyProtector | Where-Object -Filter { $_.KeyProtectorType -eq 'TpmPin' }) {
  Write-BasicLog -Message "TpmPin protector already exists. PIN already set"
  Disable-ScheduledTask -TaskName $BdePinTask -TaskPath "\" -ErrorAction SilentlyContinue
  Stop-Transcript
  Exit 0
}

# Check if we should run
if ((Get-Process -Name Explorer) -and (Get-BitLockerStatus)) {
  # Run Popup.ps1 via ServiceUI for user interaction
  Write-BasicLog -Message "Prompting user to set BitLocker Pin"
  Set-Location -Path $PSScriptRoot
  .\ServiceUI.exe -process:Explorer.exe "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -WindowStyle Hidden -Ex bypass -file "\`"$($PSScriptRoot)\Popup.ps1\`""
  $exitCode = $LASTEXITCODE

  if ($exitCode -eq 0 -and ((Get-BitLockerVolume -MountPoint $env:SystemDrive).KeyProtector | Where-Object -Filter { $_.KeyProtectorType -eq 'TpmPin' })) {
    # Pin set, disable scheduled task
    Write-BasicLog -Message "TpmPin protector successfully set"
    Disable-ScheduledTask -TaskName $BdePinTask -TaskPath "\" -ErrorAction SilentlyContinue | Out-Null
  }
  elseif ($exitCode = 1223) {
    # User cancelled prompt
    Write-BasicLog -Message "User cancelled prompt!"
  }
  else {
    # Something went wrong
    Write-BasicLog -Message "Something went wrong!"
  }
}
else {
  # Write to log
  Write-BasicLog -Message "Requirements not met"
}

# Stop logging
Write-BasicLog -Message ("*" * 40)
