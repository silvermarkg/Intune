# --| Create Scheduled Task to prompt user to enter Bitlocker PIN
# --| Script will copy all the binaries to "C:\Program Files\BDEPIN" and create the sched task.
# --| Troubleshooting log (PIN.log) is created in the above folder. 
# --| M.Balzan (CE) 01/10/2020
# --| M.Goodman 30-Jun-2022 (updated to suit my environment)
# --| Version 1.0 | Original
# --| Version 1.1 | Added UseEnhancedPIN reg entry for Popup call & set Sched task trigger to Startup
# --| Version 1.2 | Updated to nag user every 10 mins. Also changed to suit my environment
# --| Version 1.3 | Updated scheduled task to ensure prompt is run as soon as and repeats as soon as

# Define variables
$Path = "$($env:ProgramFiles)\BDEPIN"

# --| Create binaries folder if not found.
if(-Not (Test-Path $Path)) {
  New-Item -Path $Path -ItemType Directory -Force
}

Start-Transcript "$($Path)\BDEPIN_Install.log"

# --| Copy all binaries to PIN folder
Copy-Item -Path $PSScriptRoot\* -Destination $Path -Force 

# --| Create schedule task to launch user PIN pop-up
$stAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$($Path)\SetBitLockerPin.ps1`""
#$stTrigger = New-ScheduledTaskTrigger -AtLogOn
$stTrigger = New-ScheduledTaskTrigger -Daily -DaysInterval 1 -At (Get-Date -Hour 7 -Minute 0 -Second 0)
$stRepeatTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date -Hour 7 -Minute 0 -Second 0) -RepetitionDuration (New-TimeSpan -Hours 12) -RepetitionInterval (New-TimeSpan -Minutes 10)
$stRepeatTrigger.Repetition.StopAtDurationEnd = $false
$stTrigger.Repetition = $stRepeatTrigger.Repetition
$stPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
$stSettings = New-ScheduledTaskSettingsSet -StartWhenAvailable:$false -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 12) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Priority 4
$BdePinTask = Register-ScheduledTask -TaskName "Set-BitLocker-PIN" -TaskPath "\" -Action $stAction -Trigger $stTrigger -Principal $stPrincipal -Settings $stSettings -Description "Prompt user to set BitLocker PIN"

# Stop logging and exit
Stop-Transcript
Exit 0
