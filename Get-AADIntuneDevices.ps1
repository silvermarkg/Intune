[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)] [ValidateNotNullOrEmpty()] [String] $SerialNumber = "*"
)

Process {

    Import-Module WindowsAutopilotIntune -Scope Global
    Import-Module AzureAD -Scope Global
    $intuneId = Connect-MSGraph
    $aadId = Connect-AzureAD -AccountId $intuneId.UPN

    # Determine which Autopilot devices to process
    if ($SerialNumber -ne "*") {
        # Get specific device (by serial number)
        $IntuneParams = @{
            Serial = $SerialNumber
        }
    }

    # Data gathering
    Write-Host -Object "Gathering devices..."
    $aadDevices = Get-AzureADDevice -All $true
    $intuneDevices = Get-IntuneManagedDevice -Filter "contains(operatingsystem, 'Windows')" | Get-MSGraphAllPages

    # Maintain a list of devices to remove
    $extra = @()

    # Process each Autopilot device
    $intuneDevices | % {

        # Find the objects linked to the Autopilot device
        $currentIntuneDevice = $_
        $relatedIntuneAadDevice = $aadDevices | ? { $_.DeviceId -eq $currentIntuneDevice.azureADDeviceId }

        if ($null -eq $relatedIntuneAadDevice) {
            # Display a summary for this device
            Write-Host "$($currentIntuneDevice.SerialNumber):"
            Write-Host "  Intune:    = $($currentIntuneDevice.DeviceName)" -ForegroundColor Green
            #Write-Host "  AAD:Intune = $($relatedIntuneAadDevice.DisplayName) [$($relatedIntuneAadDevice.DeviceTrustType)]" -ForegroundColor Green
            Write-Host "  Missing AAD device!" -ForegroundColor Red
        
            $matchedDevices = $aadDevices | ? { $_.DisplayName -eq $currentIntuneDevice.DeviceName }

            # If there are no devices in AAD with this ZTDID, the pre-created device was removed - that's bad
            if ($matchedDevices.Count -gt 0) {
                            # We would normally expect one AAD device for AAD Join scenarios, and two for Hybrid AAD Join scenarios, but there can be more
                Write-Host "  $($matchedDevices.Count) devices found with same name"

                $matchedDevices | % { 
                    if ($_.DeviceId -ne $relatedIntuneAadDevice.DeviceId) {
                        Write-Host "  AAD        = $($_.DisplayName) [$($_.DeviceTrustType)]"
                    }
                }
            }

            $currentIntuneDevice.ManagementName
        }
    }
}
