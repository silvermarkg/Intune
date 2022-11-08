# Define variables
$Path = "$($env:ProgramFiles)\BDEPIN"

# Remove app folder
if(Test-Path $Path -PathType Container) {
  Remove-Item -Path $Path -Recurse -Force
}

# Remove scheduled task
Unregister-ScheduledTask -TaskName "Set-BitLocker-PIN" -TaskPath "\" -Confirm:$false
