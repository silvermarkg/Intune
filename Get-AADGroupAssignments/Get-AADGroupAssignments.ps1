# Pretty sure this came from someone else, but cannot remember who. If it's yours, let me know so I can attribute credit

[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Low")]
param (
    [Parameter(Mandatory=$true,ParameterSetName="Name")]
    [ValidateNotNullOrEmpty()]
    [String]$Name,

    [Parameter(Mandatory=$true,ParameterSetName="ID")]
    [ValidateNotNullOrEmpty()]
    [String]$Id
)

# Connect and change schema 
Connect-MSGraph -ForceInteractive
Update-MSGraphEnvironment -SchemaVersion beta
Connect-MSGraph
 
#$Groups = Get-AADGroup | Get-MSGraphAllPages
if ($PSCmdlet.ParameterSetName -eq "Name") {
  $Group = Get-AADGroup -Filter "displayname eq '$GroupName'"
}
else {
  $Group = Get-AADGroup -groupId $Id
}
if ($null -eq $Group) {
    # Could not find group
    Write-Warning -Message "Failed to find group!"
    exit
}
 
#### Config Don't change
 
Write-host "AAD Group Name: $($Group.displayName)" -ForegroundColor Green
 
# Apps
$AllAssignedApps = Get-IntuneMobileApp -Filter "isAssigned eq true" -Select id, displayName, lastModifiedDateTime, assignments -Expand assignments | Where-Object {$_.assignments -match $Group.id}
Write-host "Number of Apps found: $($AllAssignedApps.DisplayName.Count)" -ForegroundColor cyan
Foreach ($Config in $AllAssignedApps) {
 
Write-host $Config.displayName -ForegroundColor Yellow
 
}
 
 
# Device Compliance
$AllDeviceCompliance = Get-IntuneDeviceCompliancePolicy -Select id, displayName, lastModifiedDateTime, assignments -Expand assignments | Where-Object {$_.assignments -match $Group.id}
Write-host "Number of Device Compliance policies found: $($AllDeviceCompliance.DisplayName.Count)" -ForegroundColor cyan
Foreach ($Config in $AllDeviceCompliance) {
 
Write-host $Config.displayName -ForegroundColor Yellow
 
}
 
 
# Device Configuration
### THIS IS CURRENTLY FAILING ###
$AllDeviceConfig = Get-IntuneDeviceConfigurationPolicy -Select id, displayName, lastModifiedDateTime, assignments -Expand assignments | Where-Object {$_.assignments -match $Group.id}
Write-host "Number of Device Configurations found: $($AllDeviceConfig.DisplayName.Count)" -ForegroundColor cyan
Foreach ($Config in $AllDeviceConfig) {
 
Write-host $Config.displayName -ForegroundColor Yellow
 
}
 
# Settings Catalog Configuration
$AllSettingsCatalogConfig = Invoke-MSGraphRequest -HttpMethod GET -Url "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies" -Get-IntuneDeviceConfigurationPolicy -Select id, displayName, lastModifiedDateTime, assignments -Expand assignments | Where-Object { $_.assignments -match $Group.id }
Write-host "Number of Device Configurations found: $($AllDeviceConfig.DisplayName.Count)" -ForegroundColor cyan
Foreach ($Config in $AllDeviceConfig) {
 
    Write-host $Config.displayName -ForegroundColor Yellow
 
}

# Device Configuration Powershell Scripts 
$Resource = "deviceManagement/deviceManagementScripts"
$graphApiVersion = "Beta"
$uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$expand=groupAssignments"
$DMS = Invoke-MSGraphRequest -HttpMethod GET -Url $uri
$AllDeviceConfigScripts = $DMS.value | Where-Object {$_.assignments -match $Group.id}
Write-host "Number of Device Configurations Powershell Scripts found: $($AllDeviceConfigScripts.DisplayName.Count)" -ForegroundColor cyan
 
Foreach ($Config in $AllDeviceConfigScripts) {
 
Write-host $Config.displayName -ForegroundColor Yellow
 
}
 
 
 
# Administrative templates
$Resource = "deviceManagement/groupPolicyConfigurations"
$graphApiVersion = "Beta"
$uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$expand=Assignments"
$ADMT = Invoke-MSGraphRequest -HttpMethod GET -Url $uri
$AllADMT = $ADMT.value | Where-Object {$_.assignments -match $Group.id}
Write-host "Number of Device Administrative Templates found: $($AllADMT.DisplayName.Count)" -ForegroundColor cyan
Foreach ($Config in $AllADMT) {
 
Write-host $Config.displayName -ForegroundColor Yellow
 
}