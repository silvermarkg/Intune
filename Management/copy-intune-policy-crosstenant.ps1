#[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Scope='Function', Target='Get-MSGraphAllPages')]
<#PSScriptInfo
.VERSION 6.0.3
.GUID ec2a6c43-35ad-48cd-b23c-da987f1a528b
.AUTHOR AndrewTaylor
.DESCRIPTION Copies any Intune Policy via Microsoft Graph to "Copy of (policy name)".  Displays list of policies using GridView to select which to copy.  Cross tenant version
.COMPANYNAME 
.COPYRIGHT GPL
.TAGS intune endpoint MEM environment
.LICENSEURI https://github.com/andrew-s-taylor/public/blob/main/LICENSE
.PROJECTURI https://github.com/andrew-s-taylor/public
.ICONURI 
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS 
.EXTERNALSCRIPTDEPENDENCIES 
.RELEASENOTES
#>
<#
.SYNOPSIS
  Copies an Intune Policy.  Cross tenant version
.DESCRIPTION
Copies any Intune Policy via Microsoft Graph to "Copy of (policy name)".  Displays list of policies using GridView to select which to copy.  Cross tenant version

.INPUTS
None
.OUTPUTS
Creates a log file in %Temp%
.NOTES
  Version:        6.0.3
  Author:         Andrew Taylor
  WWW:            andrewstaylor.com
  Creation Date:  25/07/2022
  Updated: 27/02/2023
  Purpose/Change: Initial script development
  Change: Added support for multiple policy selection
  Change: Added Module installation
  Change: Declared $configuration as array
  Change: Amended Encoding for Applocker Policies
  Change: Added support for GPO Admin Templates
  Change: Fix for non custom admin templates
  Change: Added better credential management
  Change: Added AzureAD module connection
  Change: Added support for Conditional Access policies
  Change: Added support for Proactive Remediations
  Change: Added support for AAD Groups
  Change: Fixed issue with multiple admin templates (passed ID in array variable)
  Change: Switched to Graph Authentication API
  Change: Removed error text when looping through policies to inspect
  Change: Fixed Syntax on omaSettings
  Change: Added scope for CA policies
  Change: Added support for Winget Store Apps
  Change: Fixed issue with security policies
  Change: Added support for PowerShell Scripts
  Change: Added support for W365 Provisioning Policies
  Change: Added support for W365 User Settings Policies
  Change: Added support for Policy Sets
  Change: Added support for Enrollment Configuration Policies
  Change: Added support for Device Categories
  Change: Added support for Device Filters
  Change: Added support for Branding Profiles
  Change: Added support for Admin Approvals
  Change: Added support for Intune Terms
  Change: Added support for custom roles
  Change: Added fix for large Settings Catalog Policies (thanks Jordan in the blog comments)
  Change: Added support for pagination when grabbing Settings Catalog policies (thanks to randomsunrize on GitHub)
  Change: Switched do-until for while loop for pagination
  Change: Added Automation Support
  Change: Added parameters for name, ID and tenant details
  Change: Added find ID by name functionality
  Change: Fixed pagination link
  Change: Added scopes for Win365
  Change: Added support for custom compliance scripts
  Change: Performance improvement (significantly faster)
  Change: Removed pagination error (whitespace)
  Change: Bug fix when calling by ID alone

  
.EXAMPLE
N/A
#>
##################################################################################################################################
#################                                                  PARAMS                                        #################
##################################################################################################################################

[cmdletbinding()]
    
param
(
    [string[]]$name #Item Name
    ,  
    [string[]]$id #Item ID
    ,  
    [string]$everything #Copies EVERYTHING
    ,  
    [string]$sourcetenant #Source Tenant
    ,  
    [string]$desttenant #Destination Tenant
    )

##################################################################################################################################
#################                                                  INITIALIZATION                                #################
##################################################################################################################################

##Check if parameters have been set
$namecheck = $PSBoundParameters.ContainsKey('name')
$idcheck = $PSBoundParameters.ContainsKey('id')
$everythingcheck = $PSBoundParameters.ContainsKey('everything')
$sourcetenantcheck = $PSBoundParameters.ContainsKey('sourcetenant')
$desttenantcheck = $PSBoundParameters.ContainsKey('desttenant')




if ($idcheck -eq $true) {
    $inputid = $id
}
$ErrorActionPreference = "Continue"
##Start Logging to %TEMP%\intune.log
$date = get-date -format yyyyMMddTHHmmssffff
Start-Transcript -Path $env:TEMP\intune-$date.log

#Install MS Graph if not available


Write-Host "Installing Microsoft Graph modules if required (current user scope)"

#Install MS Graph if not available
Write-Host "Installing Microsoft Graph modules if required (current user scope)"

#Install MS Graph if not available
#Install MS Graph if not available
if (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication) {
    Write-Host "Microsoft Graph Authentication Already Installed"
} 
else {
        Install-Module -Name Microsoft.Graph.Authentication -Scope CurrentUser -Repository PSGallery -Force -RequiredVersion 1.19.0 
        Write-Host "Microsoft Graph Authentication Installed"
}

#Install MS Graph if not available
if (Get-Module -ListAvailable -Name microsoft.graph.devices.corporatemanagement ) {
    Write-Host "Microsoft Graph Corporate Management Already Installed"
} 
else {
        Install-Module -Name microsoft.graph.devices.corporatemanagement  -Scope CurrentUser -Repository PSGallery -Force -RequiredVersion 1.19.0  
        Write-Host "Microsoft Graph Corporate Management Installed"
    }

    if (Get-Module -ListAvailable -Name Microsoft.Graph.Groups) {
        Write-Host "Microsoft Graph Groups Already Installed "
    } 
    else {
            Install-Module -Name Microsoft.Graph.Groups -Scope CurrentUser -Repository PSGallery -Force -RequiredVersion 1.19.0  
            Write-Host "Microsoft Graph Groups Installed"
    }
    
    #Install MS Graph if not available
    if (Get-Module -ListAvailable -Name Microsoft.Graph.DeviceManagement) {
        Write-Host "Microsoft Graph DeviceManagement Already Installed"
    } 
    else {
            Install-Module -Name Microsoft.Graph.DeviceManagement -Scope CurrentUser -Repository PSGallery -Force -RequiredVersion 1.19.0  
            Write-Host "Microsoft Graph DeviceManagement Installed"
    }

    #Install MS Graph if not available
    if (Get-Module -ListAvailable -Name Microsoft.Graph.identity.signins) {
        Write-Host "Microsoft Graph Identity SignIns Already Installed"
    } 
    else {
            Install-Module -Name Microsoft.Graph.Identity.SignIns -Scope CurrentUser -Repository PSGallery -Force -RequiredVersion 1.19.0  
            Write-Host "Microsoft Graph Identity SignIns Installed"
    }



# Load the Graph module
Import-Module microsoft.graph.authentication
import-module Microsoft.Graph.Identity.SignIns
import-module Microsoft.Graph.DeviceManagement
import-module microsoft.Graph.Groups
import-module microsoft.graph.devices.corporatemanagement



##Disconnect just in case anything is lingering
Disconnect-MgGraph

Function Get-ScriptVersion(){
    
    <#
    .SYNOPSIS
    This function is used to check if the running script is the latest version
    .DESCRIPTION
    This function checks GitHub and compares the 'live' version with the one running
    .EXAMPLE
    Get-ScriptVersion
    Returns a warning and URL if outdated
    .NOTES
    NAME: Get-ScriptVersion
    #>
    
    [cmdletbinding()]
    
    param
    (
        $liveuri
    )
$contentheaderraw = (Invoke-WebRequest -Uri $liveuri -Method Get)
$contentheader = $contentheaderraw.Content.Split([Environment]::NewLine)
$liveversion = (($contentheader | Select-String 'Version:') -replace '[^0-9.]','') | Select-Object -First 1
$currentversion = ((Get-Content -Path $PSCommandPath | Select-String -Pattern "Version: *") -replace '[^0-9.]','') | Select-Object -First 1
if ($liveversion -ne $currentversion) {
write-warning "Script has been updated, please download the latest version from $liveuri"
}
}
Get-ScriptVersion -liveuri "https://raw.githubusercontent.com/andrew-s-taylor/public/main/Powershell%20Scripts/Intune/copy-intune-policy-crosstenant.ps1"


############################################################
############################################################
############# CHANGE THIS TO USE IN AUTOMATION #############
############################################################
############################################################
$automated = "no"
############################################################
############################################################
#############           AUTOMATION NOTES       #############
############################################################

## You need to add these modules to your Automation Account if using Azure Automation
## Don't use the V2 preview versions
## https://www.powershellgallery.com/packages/PackageManagement/1.4.8.1
## https://www.powershellgallery.com/packages/Microsoft.Graph.Authentication/1.19.0
## https://www.powershellgallery.com/packages/Microsoft.Graph.Devices.CorporateManagement/1.19.0
## https://www.powershellgallery.com/packages/Microsoft.Graph.Groups/1.19.0
## https://www.powershellgallery.com/packages/Microsoft.Graph.DeviceManagement/1.19.0
## https://www.powershellgallery.com/packages/Microsoft.Graph.Identity.SignIns/1.19.0

if ($automated -eq "yes") {
    ##################################################################################################################################
    #################                                                  VARIABLES                                     #################
    ##################################################################################################################################
    
  
    $clientid = "YOUR_AAD_REG_ID"
    
    $clientsecret = "YOUR_CLIENT_SECRET"
    
    ##Only use if not set in script parameters
    if ($sourcetenantcheck -ne $true) {
    $sourcetenant = "TENANT_ID"
    }
     ##Only use if not set in script parameters
    if ($desttenantcheck -ne $true) {
    $desttenant = "TENANT_ID"
    }   
    
    ##################################################################################################################################
    #################                                             END  VARIABLES                                     #################
    ##################################################################################################################################
    }
###############################################################################################################
######                                          Add Functions                                            ######
###############################################################################################################

Function Get-IntuneApplication(){
    
    <#
    .SYNOPSIS
    This function is used to get applications from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any applications added
    .EXAMPLE
    Get-IntuneApplication
    Returns any applications configured in Intune
    .NOTES
    NAME: Get-IntuneApplication
    #>
    
    [cmdletbinding()]
    
    param
    (
        $id
    )
    
    $graphApiVersion = "Beta"
    $Resource = "deviceAppManagement/mobileApps"
    
        try {
    
            if($id){
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$id"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
    
            }
    
            else {
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value | Where-Object { ($_.'@odata.type').Contains("#microsoft.graph.winGetApp") }
    
            }
    
        }
    
        catch {
    
        }
    
    }



Function Get-DeviceConfigurationPolicyGP(){
    
    <#
    .SYNOPSIS
    This function is used to get device configuration policies from the Graph API REST interface - Group Policies
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any device configuration policies
    .EXAMPLE
    Get-DeviceConfigurationPolicy
    Returns any device configuration policies configured in Intune
    .NOTES
    NAME: Get-DeviceConfigurationPolicyGP
    #>
    
    [cmdletbinding()]
    
    param
    (
        $id
    )
    
    $graphApiVersion = "beta"
    $DCP_resource = "deviceManagement/groupPolicyConfigurations"
    
    try {
            if($id){
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)?`$filter=id eq '$id'"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).value
    
            }
    
            else {
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
            }
        }
        catch {}
     
}


#############################################################################################################    

Function Get-ConditionalAccessPolicy(){
    
    <#
    .SYNOPSIS
    This function is used to get conditional access policies from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any conditional access policies
    .EXAMPLE
    Get-ConditionalAccessPolicy
    Returns any conditional access policies in Azure
    .NOTES
    NAME: Get-ConditionalAccessPolicy
    #>
    
    [cmdletbinding()]
    
    param
    (
        $id
    )
    

    $graphApiVersion = "beta"
    $DCP_resource = "identity/conditionalAccess/policies"
    
    try {
            if($id){
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)/$id"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
    
            }
    
            else {
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
    
            }
        }
        catch {}
    
     
}

####################################################

Function Get-DeviceConfigurationPolicy(){
    
    <#
    .SYNOPSIS
    This function is used to get device configuration policies from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any device configuration policies
    .EXAMPLE
    Get-DeviceConfigurationPolicy
    Returns any device configuration policies configured in Intune
    .NOTES
    NAME: Get-DeviceConfigurationPolicy
    #>
    
    [cmdletbinding()]
    
    param
    (
        $id
    )
    
    $graphApiVersion = "beta"
    $DCP_resource = "deviceManagement/deviceConfigurations"
    
    try {
            if($id){
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)?`$filter=id eq '$id'"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).value
    
            }
    
            else {
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
            }
        }
        catch {}
    
        
}
    
##########################################################################################

Function Get-GroupPolicyConfigurationsDefinitionValues()
{
	
    <#
    .SYNOPSIS
    This function is used to get device configuration policies from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any device configuration policies
    .EXAMPLE
    Get-DeviceConfigurationPolicy
    Returns any device configuration policies configured in Intune
    .NOTES
    NAME: Get-GroupPolicyConfigurations
    #>
	
	[cmdletbinding()]
	Param (
		
		[Parameter(Mandatory = $true)]
		[string]$GroupPolicyConfigurationID
		
	)
	
	$graphApiVersion = "Beta"
	#$DCP_resource = "deviceManagement/groupPolicyConfigurations/$GroupPolicyConfigurationID/definitionValues?`$filter=enabled eq true"
	$DCP_resource = "deviceManagement/groupPolicyConfigurations/$GroupPolicyConfigurationID/definitionValues"
	
	try {	
		$uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
		(Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
		
    }
    catch{}
	

	
}

####################################################
Function Get-GroupPolicyConfigurationsDefinitionValuesPresentationValues()
{
	
    <#
    .SYNOPSIS
    This function is used to get device configuration policies from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any device configuration policies
    .EXAMPLE
    Get-DeviceConfigurationPolicy
    Returns any device configuration policies configured in Intune
    .NOTES
    NAME: Get-GroupPolicyConfigurations
    #>
	
	[cmdletbinding()]
	Param (
		
		[Parameter(Mandatory = $true)]
		[string]$GroupPolicyConfigurationID,
		[string]$GroupPolicyConfigurationsDefinitionValueID
		
	)
	$graphApiVersion = "Beta"
	
	$DCP_resource = "deviceManagement/groupPolicyConfigurations/$GroupPolicyConfigurationID/definitionValues/$GroupPolicyConfigurationsDefinitionValueID/presentationValues"
	try {
		$uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
		(Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    }
    catch {}
		
	
}

Function Get-GroupPolicyConfigurationsDefinitionValuesdefinition ()
{
   <#
    .SYNOPSIS
    This function is used to get device configuration policies from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any device configuration policies
    .EXAMPLE
    Get-DeviceConfigurationPolicy
    Returns any device configuration policies configured in Intune
    .NOTES
    NAME: Get-GroupPolicyConfigurations
    #>
	
	[cmdletbinding()]
	Param (
		
		[Parameter(Mandatory = $true)]
		[string]$GroupPolicyConfigurationID,
		[Parameter(Mandatory = $true)]
		[string]$GroupPolicyConfigurationsDefinitionValueID
		
	)
	$graphApiVersion = "Beta"
	$DCP_resource = "deviceManagement/groupPolicyConfigurations/$GroupPolicyConfigurationID/definitionValues/$GroupPolicyConfigurationsDefinitionValueID/definition"
	try {
		
		$uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
		
		$responseBody = Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject
    }
    catch{}
		
		
	$responseBody
}


Function Get-GroupPolicyDefinitionsPresentations ()
{
   <#
    .SYNOPSIS
    This function is used to get device configuration policies from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any device configuration policies
    .EXAMPLE
    Get-DeviceConfigurationPolicy
    Returns any device configuration policies configured in Intune
    .NOTES
    NAME: Get-GroupPolicyConfigurations
    #>
	
	[cmdletbinding()]
	Param (
		
		
		[Parameter(Mandatory = $true)]
		[string]$groupPolicyDefinitionsID,
		[Parameter(Mandatory = $true)]
		[string]$GroupPolicyConfigurationsDefinitionValueID
		
	)
	$graphApiVersion = "Beta"
	$DCP_resource = "deviceManagement/groupPolicyConfigurations/$groupPolicyDefinitionsID/definitionValues/$GroupPolicyConfigurationsDefinitionValueID/presentationValues?`$expand=presentation"
		$uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
		try {
		(Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value.presentation
        }
        catch {}
		
	
}


####################################################
    
Function Get-DeviceConfigurationPolicySC(){
    
            <#
            .SYNOPSIS
            This function is used to get device configuration policies from the Graph API REST interface - SETTINGS CATALOG
            .DESCRIPTION
            The function connects to the Graph API Interface and gets any device configuration policies
            .EXAMPLE
            Get-DeviceConfigurationPolicySC
            Returns any device configuration policies configured in Intune
            .NOTES
            NAME: Get-DeviceConfigurationPolicySC
            #>
            
            [cmdletbinding()]
            
            param
            (
                $id
            )
            
            $graphApiVersion = "beta"
            $DCP_resource = "deviceManagement/configurationPolicies"
            try {
                    if($id){
            
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)?`$filter=id eq '$id'"
                    (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).value
            
                    }
            
                    else {

                        $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
                        $allconfigurationsettingscatalogpages = @()
                        $configurationsettingscatalog = Invoke-MgGraphRequest -Uri $uri -Method Get
                        $allconfigurationsettingscatalogpages += $configurationsettingscatalog.value
                                $policynextlink = $configurationsettingscatalog."@odata.nextlink"
                                $policynextlink = $policynextlink -replace '\S', ''
                                while (($policynextlink -ne "") -and ($null -ne $policynextlink))
                                {
                $nextsettings = (Invoke-MgGraphRequest -Uri $policynextlink -Method Get -OutputType PSObject)
                $policynextlink = $nextsettings."@odata.nextLink"
                $policynextlink = $policynextlink -replace '\S', ''
                $allconfigurationsettingscatalogpages += $nextsettings.value
            }

                
                        $configurationsettingscatalog = $allconfigurationsettingscatalogpages
                        $configurationsettingscatalog
                
                        }
                }
                catch {}
            
            
}
            
################################################################################################


####################################################
    
Function Get-DeviceProactiveRemediations(){
    
    <#
    .SYNOPSIS
    This function is used to get device proactive remediations from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any device proactive remediations
    .EXAMPLE
    Get-DeviceproactiveRemediations
    Returns any device proactive remediations configured in Intune
    .NOTES
    NAME: Get-Deviceproactiveremediations
    #>
    
    [cmdletbinding()]
    
    param
    (
        $id
    )
    
    $graphApiVersion = "beta"
    $DCP_resource = "deviceManagement/devicehealthscripts"
    try {
            if($id){
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)/$id"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
    
            }
    
            else {
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
            }
        }
        catch {}
    
   
}
    
################################################################################################

####################################################
    
Function Get-DeviceManagementScripts(){
    
    <#
    .SYNOPSIS
    This function is used to get device PowerShell scripts from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any device scripts
    .EXAMPLE
    Get-DeviceManagementScripts
    Returns any device management scripts configured in Intune
    .NOTES
    NAME: Get-DeviceManagementScripts
    #>
    
    [cmdletbinding()]
    
    param
    (
        $id
    )
    
    $graphApiVersion = "beta"
    $DCP_resource = "deviceManagement/devicemanagementscripts"
    try {
            if($id){
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)/$id"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
    
            }
    
            else {
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
            }
        }
        catch {}
    
   
}
    
################################################################################################

    
Function Get-DeviceCompliancePolicy(){
    
            <#
            .SYNOPSIS
            This function is used to get device compliance policies from the Graph API REST interface
            .DESCRIPTION
            The function connects to the Graph API Interface and gets any device compliance policies
            .EXAMPLE
            Get-DeviceCompliancepolicy
            Returns any device compliance policies configured in Intune
            .NOTES
            NAME: Get-devicecompliancepolicy
            #>
            
            [cmdletbinding()]
            
            param
            (
                $id
            )
            
            $graphApiVersion = "beta"
            $DCP_resource = "deviceManagement/deviceCompliancePolicies"
            try {
                    if($id){
            
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)?`$filter=id eq '$id'"
                    (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).value
            
                    }
            
                    else {
            
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
                    (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
            
                    }
                }
                catch {}
            
}

Function Get-DeviceCompliancePolicyScripts(){
    
    <#
    .SYNOPSIS
    This function is used to get device custom compliance policy scripts from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any device compliance policies
    .EXAMPLE
    Get-DeviceCompliancePolicyScripts
    Returns any device compliance policy scripts configured in Intune
    .NOTES
    NAME: Get-DeviceCompliancePolicyScripts
    #>
    
    [cmdletbinding()]
    
    param
    (
        $id
    )
    
    $graphApiVersion = "beta"
    $DCP_resource = "deviceManagement/deviceComplianceScripts"
    try {
            if($id){
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)/$id"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
    
            }
    
            else {
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
            }
        }
        catch {}
    
}
            
#################################################################################################
Function Get-DeviceSecurityPolicy(){
    
            <#
            .SYNOPSIS
            This function is used to get device security policies from the Graph API REST interface
            .DESCRIPTION
            The function connects to the Graph API Interface and gets any device security policies
            .EXAMPLE
            Get-DeviceSecurityPolicy
            Returns any device compliance policies configured in Intune
            .NOTES
            NAME: Get-DeviceSecurityPolicy
            #>
            
            [cmdletbinding()]
            
            param
            (
                $id
            )
            
            $graphApiVersion = "beta"
            $DCP_resource = "deviceManagement/intents"
            try {
                    if($id){
            
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)?`$filter=id eq '$id'"
                    (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).value
            
                    }
            
                    else {
            
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
                    (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
            
                    }
                }
                catch {}
           
}

#################################################################################################  

Function Get-ManagedAppProtectionAndroid(){

    <#
    .SYNOPSIS
    This function is used to get managed app protection configuration from the Graph API REST interface Android
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any managed app protection policy Android
    .EXAMPLE
    Get-ManagedAppProtectionAndroid
    .NOTES
    NAME: Get-ManagedAppProtectionAndroid
    #>
    
    param
    (
        $id
    )
    $graphApiVersion = "Beta"
    
            $Resource = "deviceAppManagement/androidManagedAppProtections"
        try {
            if($id){
            
                $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource('$id')"
                (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
        
                }
        
                else {
        
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
                    Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject  
        
                }
            }
            catch {}        
        
        
    
}

#################################################################################################  

Function Get-ManagedAppProtectionIOS(){

    <#
    .SYNOPSIS
    This function is used to get managed app protection configuration from the Graph API REST interface IOS
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any managed app protection policy IOS
    .EXAMPLE
    Get-ManagedAppProtectionIOS
    .NOTES
    NAME: Get-ManagedAppProtectionIOS
    #>
    param
    (
        $id
    )

    $graphApiVersion = "Beta"
    
                $Resource = "deviceAppManagement/iOSManagedAppProtections"
        try {
                if($id){
            
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource('$id')"
                    (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
            
                    }
            
                    else {
            
                        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
                        Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject
            
                    }
                }
                catch {}
        
}
    
####################################################
Function Get-GraphAADGroups(){
    
    <#
    .SYNOPSIS
    This function is used to get AAD Groups from the Graph API REST interface 
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any AAD Groups
    .EXAMPLE
    Get-GraphAADGroups
    Returns any AAD Groups
    .NOTES
    NAME: Get-GraphAADGroups
    #>
    
    [cmdletbinding()]
    
    param
    (
        $id
    )
    
    $graphApiVersion = "beta"
    $DCP_resource = "Groups"
    try {
            if($id){
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)/$id"
            Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject
    
            }
    
            else {
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)?`$Filter=onPremisesSyncEnabled ne true&`$count=true"
            #(Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
            Get-MgGroup | Where-Object OnPremisesSyncEnabled -NE true
    
            }
        }
        catch {}
    
}

#################################################################################################  

Function Get-AutoPilotProfile(){
    
                <#
                .SYNOPSIS
                This function is used to get autopilot profiles from the Graph API REST interface 
                .DESCRIPTION
                The function connects to the Graph API Interface and gets any autopilot profiles
                .EXAMPLE
                Get-AutoPilotProfile
                Returns any autopilot profiles configured in Intune
                .NOTES
                NAME: Get-AutoPilotProfile
                #>
                
                [cmdletbinding()]
                
                param
                (
                    $id
                )
                
                $graphApiVersion = "beta"
                $DCP_resource = "deviceManagement/windowsAutopilotDeploymentProfiles"
                try {
                        if($id){
                
                        $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)?`$filter=id eq '$id'"
                        (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).value
                
                        }
                
                        else {
                
                        $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
                        (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
                
                        }
                    }
                    catch {}
                
}

#################################################################################################

Function Get-AutoPilotESP(){
    
                    <#
                    .SYNOPSIS
                    This function is used to get autopilot ESP from the Graph API REST interface 
                    .DESCRIPTION
                    The function connects to the Graph API Interface and gets any autopilot ESP
                    .EXAMPLE
                    Get-AutoPilotESP
                    Returns any autopilot ESPs configured in Intune
                    .NOTES
                    NAME: Get-AutoPilotESP
                    #>
                    
                    [cmdletbinding()]
                    
                    param
                    (
                        $id
                    )
                    
                    $graphApiVersion = "beta"
                    $DCP_resource = "deviceManagement/deviceEnrollmentConfigurations"
                    try {
                            if($id){
                    
                            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)?`$filter=id eq '$id'"
                            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).value
                    
                            }
                    
                            else {
                    
                            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
                            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
                    
                            }
                        }
                        catch{}
}
                
#################################################################################################    

Function Get-DecryptedDeviceConfigurationPolicy(){

    <#
    .SYNOPSIS
    This function is used to decrypt device configuration policies from an json array with the use of the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and decrypt Windows custom device configuration policies that is encrypted
    .EXAMPLE
    Decrypt-DeviceConfigurationPolicy -dcps $DCPs
    Returns any device configuration policies configured in Intune in clear text without encryption
    .NOTES
    NAME: Decrypt-DeviceConfigurationPolicy
    #>
    
    [cmdletbinding()]
    
    param
    (
        $dcpid
    )
    
    $graphApiVersion = "Beta"
    $DCP_resource = "deviceManagement/deviceConfigurations"
    $dcp = Get-DeviceConfigurationPolicy -id $dcpid
        if ($dcp.'@odata.type' -eq "#microsoft.graph.windows10CustomConfiguration") {
            # Convert policy of type windows10CustomConfiguration
            foreach ($omaSetting in $dcp.omaSettings) {
                    if ($omaSetting.isEncrypted -eq $true) {
                        $DCP_resource_function = "$($DCP_resource)/$($dcp.id)/getOmaSettingPlainTextValue(secretReferenceValueId='$($omaSetting.secretReferenceValueId)')"
                        $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource_function)"
                        $value = ((Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value)

                        #Remove any unnecessary properties
                        $omaSetting.PsObject.Properties.Remove("isEncrypted")
                        $omaSetting.PsObject.Properties.Remove("secretReferenceValueId")
                        $omaSetting.value = $value
                    }

            }
        }
    
    $dcp

}

Function Get-Win365UserSettings(){
    
    <#
    .SYNOPSIS
    This function is used to get Windows 365 User Settings Policies from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any device scriptsWindows 365 User Settings Policies
    .EXAMPLE
    Get-Win365UserSettings
    Returns any Windows 365 User Settings Policies configured in Intune
    .NOTES
    NAME: Get-Win365UserSettings
    #>
    
    [cmdletbinding()]
    
    param
    (
        $id
    )
    
    $graphApiVersion = "beta"
    $DCP_resource = "deviceManagement/virtualEndpoint/userSettings"
    try {
            if($id){
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)/$id"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
    
            }
    
            else {
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
            }
        }
        catch {}
    
   
}

Function Get-Win365ProvisioningPolicies(){
    
    <#
    .SYNOPSIS
    This function is used to get Windows 365 Provisioning Policies from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any device scriptsWindows 365 Provisioning Policies
    .EXAMPLE
    Get-Win365ProvisioningPolicies
    Returns any Windows 365 Provisioning Policies configured in Intune
    .NOTES
    NAME: Get-Win365ProvisioningPolicies
    #>
    
    [cmdletbinding()]
    
    param
    (
        $id
    )
    
    $graphApiVersion = "beta"
    $DCP_resource = "deviceManagement/virtualEndpoint/provisioningPolicies"
    try {
            if($id){
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)/$id"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
    
            }
    
            else {
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
            }
        }
        catch {}
    
   
}

Function Get-IntunePolicySets(){
    
    <#
    .SYNOPSIS
    This function is used to get Intune policy sets from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any Intune policy sets
    .EXAMPLE
    Get-IntunePolicySets
    Returns any policy sets configured in Intune
    .NOTES
    NAME: Get-IntunePolicySets
    #>
    
    [cmdletbinding()]
    
    param
    (
        $id
    )
    
    $graphApiVersion = "beta"
    $DCP_resource = "deviceAppManagement/policySets"
    try {
            if($id){
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)/$($id)?`$expand=items"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
    
            }
    
            else {
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
            }
        }
        catch {}
    
   
}

Function Get-EnrollmentConfigurations(){
    
    <#
    .SYNOPSIS
    This function is used to get Intune enrollment configurations from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any Intune enrollment configurations
    .EXAMPLE
    Get-EnrollmentConfigurations
    Returns any enrollment configurations configured in Intune
    .NOTES
    NAME: Get-EnrollmentConfigurations
    #>
    
    [cmdletbinding()]
    
    param
    (
        $id
    )
    
    $graphApiVersion = "beta"
    $DCP_resource = "deviceManagement/deviceEnrollmentConfigurations"
    try {
            if($id){
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)/$id"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
    
            }
    
            else {
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
            }
        }
        catch {}
    
   
}
    

Function Get-DeviceCategories(){
    
    <#
    .SYNOPSIS
    This function is used to get Intune device categories from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any Intune device categories
    .EXAMPLE
    Get-DeviceCategories
    Returns any device categories configured in Intune
    .NOTES
    NAME: Get-DeviceCategories
    #>
    
    [cmdletbinding()]
    
    param
    (
        $id
    )
    
    $graphApiVersion = "beta"
    $DCP_resource = "deviceManagement/deviceCategories"
    try {
            if($id){
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)/$id"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
    
            }
    
            else {
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
            }
        }
        catch {}
    
   
}


Function Get-DeviceFilters(){
    
    <#
    .SYNOPSIS
    This function is used to get Intune device filters from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any Intune device filters
    .EXAMPLE
    Get-DeviceFilters
    Returns any device filters configured in Intune
    .NOTES
    NAME: Get-DeviceFilters
    #>
    
    [cmdletbinding()]
    
    param
    (
        $id
    )
    
    $graphApiVersion = "beta"
    $DCP_resource = "deviceManagement/assignmentFilters"
    try {
            if($id){
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)/$id"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
    
            }
    
            else {
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
            }
        }
        catch {}
    
   
}


Function Get-BrandingProfiles(){
    
    <#
    .SYNOPSIS
    This function is used to get Intune Branding Profiles from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any Intune Branding Profiles
    .EXAMPLE
    Get-BrandingProfiles
    Returns any Branding Profiles configured in Intune
    .NOTES
    NAME: Get-BrandingProfiles
    #>
    
    [cmdletbinding()]
    
    param
    (
        $id
    )
    
    $graphApiVersion = "beta"
    $DCP_resource = "deviceManagement/intuneBrandingProfiles"
    try {
            if($id){
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)/$id"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
    
            }
    
            else {
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
            }
        }
        catch {}
    
   
}


Function Get-AdminApprovals(){
    
    <#
    .SYNOPSIS
    This function is used to get Intune admin approvals from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any Intune admin approvals
    .EXAMPLE
    Get-AdminApprovals
    Returns any admin approvals configured in Intune
    .NOTES
    NAME: Get-AdminApprovals
    #>
    
    [cmdletbinding()]
    
    param
    (
        $id
    )
    
    $graphApiVersion = "beta"
    $DCP_resource = "deviceManagement/operationApprovalPolicies"
    try {
            if($id){
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)/$id"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
    
            }
    
            else {
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
            }
        }
        catch {}
    
   
}

Function Get-OrgMessages(){
    
    <#
    .SYNOPSIS
    This function is used to get Intune organizational messages from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any Intune organizational messages
    .EXAMPLE
    Get-OrgMessages
    Returns any organizational messages configured in Intune
    .NOTES
    NAME: Get-OrgMessages
    #>
    
    [cmdletbinding()]
    
    param
    (
        $id
    )
    
    $graphApiVersion = "beta"
    $DCP_resource = "deviceManagement/organizationalMessageDetails"
    try {
            if($id){
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)/$id"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
    
            }
    
            else {
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
            }
        }
        catch {}
    
   
}


Function Get-IntuneTerms(){
    
    <#
    .SYNOPSIS
    This function is used to get Intune terms and conditions from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any Intune terms and conditions
    .EXAMPLE
    Get-IntuneTerms
    Returns any terms and conditions configured in Intune
    .NOTES
    NAME: Get-IntuneTerms
    #>
    
    [cmdletbinding()]
    
    param
    (
        $id
    )
    
    $graphApiVersion = "beta"
    $DCP_resource = "deviceManagement/termsAndConditions"
    try {
            if($id){
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)/$id"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
    
            }
    
            else {
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
            }
        }
        catch {}
    
   
}

Function Get-IntuneRoles(){
    
    <#
    .SYNOPSIS
    This function is used to get Intune custom roles from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any Intune custom roles
    .EXAMPLE
    Get-IntuneRoles
    Returns any custom roles configured in Intune
    .NOTES
    NAME: Get-IntuneRoles
    #>
    
    [cmdletbinding()]
    
    param
    (
        $id
    )
    
    $graphApiVersion = "beta"
    $DCP_resource = "deviceManagement/roleDefinitions"
    try {
            if($id){
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)/$id"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
    
            }
    
            else {
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value | where-object isBuiltIn -eq $False
    
            }
        }
        catch {}
    
   
}


Function Get-IntuneApplicationbyName(){
    
    <#
    .SYNOPSIS
    This function is used to get applications from the Graph API REST interface by name
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any applications added
    .EXAMPLE
    Get-IntuneApplicationbyName
    Returns any applications configured in Intune
    .NOTES
    NAME: Get-IntuneApplicationbyName
    #>
    
    [cmdletbinding()]
    
    param
    (
        $name
    )
    
    $graphApiVersion = "Beta"
    $Resource = "deviceAppManagement/mobileApps"
    
        try {
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$filter=displayname eq '$name'"
            $app = (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value | Where-Object { ($_.'@odata.type').Contains("#microsoft.graph.winGetApp") }
    
    
        }
    
        catch {
    
        }
        $myid = $app.id
        if ($null -ne $myid) {
        $fulluri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$myid"
        $type = "Winget Application"
        }
        else {
            $fulluri = ""
            $type = ""
        }
        $output = "" | Select-Object -Property id,fulluri, type    
        $output.id = $myid
        $output.fulluri = $fulluri
        $output.type = $type
        return $output
    }



Function Get-DeviceConfigurationPolicyGPbyName(){
    
    <#
    .SYNOPSIS
    This function is used to get device configuration policies from the Graph API REST interface - Group Policies
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any device configuration policies
    .EXAMPLE
    Get-DeviceConfigurationPolicyGPbyName
    Returns any device configuration policies configured in Intune
    .NOTES
    NAME: Get-DeviceConfigurationPolicyGPbyName
    #>
    
    [cmdletbinding()]
    
    param
    (
        $name
    )
    
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/groupPolicyConfigurations"
    
    try {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$filter=displayname eq '$name'"
        $GP = (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value

        }
        catch {}
        $myid = $GP.id
        if ($null -ne $myid) {
            $fulluri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$myid"
            $type = "Group Policy Configuration"
            }
            else {
                $fulluri = ""
                $type = ""
            }
            $output = "" | Select-Object -Property id,fulluri, type    
            $output.id = $myid
            $output.fulluri = $fulluri
            $output.type = $type
            return $output
    
}


#############################################################################################################    

Function Get-ConditionalAccessPolicybyName(){
    
    <#
    .SYNOPSIS
    This function is used to get conditional access policies from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any conditional access policies
    .EXAMPLE
    Get-ConditionalAccessPolicybyName
    Returns any conditional access policies in Azure
    .NOTES
    NAME: Get-ConditionalAccessPolicybyName
    #>
    
    [cmdletbinding()]
    
    param
    (
        $name
    )
    

    $graphApiVersion = "beta"
    $Resource = "identity/conditionalAccess/policies"
    
    try {

    
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$filter=displayname eq '$name'"
        $CA = (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
        }
        catch {}
        $myid = $CA.id
        if ($null -ne $myid) {
            $fulluri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$myid"
            $type = "Conditional Access"
            }
            else {
                $fulluri = ""
                $type = ""
            }
            $output = "" | Select-Object -Property id,fulluri, type    
            $output.id = $myid
            $output.fulluri = $fulluri
            $output.type = $type
            return $output
    
     
}

####################################################

Function Get-DeviceConfigurationPolicybyName(){
    
    <#
    .SYNOPSIS
    This function is used to get device configuration policies from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any device configuration policies
    .EXAMPLE
    Get-DeviceConfigurationPolicybyName
    Returns any device configuration policies configured in Intune
    .NOTES
    NAME: Get-DeviceConfigurationPolicybyName
    #>
    
    [cmdletbinding()]
    
    param
    (
        $name
    )
    
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/deviceConfigurations"
    
    try {

    
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$filter=displayname eq '$name'"
        $DC = (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
        }
        catch {}
        $myid = $DC.id
        if ($null -ne $myid) {
            $fulluri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$myid"
            $type = "Configuration Policy"
            }
            else {
                $fulluri = ""
                $type = ""
            }
            $output = "" | Select-Object -Property id,fulluri, type    
            $output.id = $myid
            $output.fulluri = $fulluri
            $output.type = $type
            return $output
    }
    
    
Function Get-DeviceConfigurationPolicySCbyName(){
    
            <#
            .SYNOPSIS
            This function is used to get device configuration policies from the Graph API REST interface - SETTINGS CATALOG
            .DESCRIPTION
            The function connects to the Graph API Interface and gets any device configuration policies
            .EXAMPLE
            Get-DeviceConfigurationPolicySCbyName
            Returns any device configuration policies configured in Intune
            .NOTES
            NAME: Get-DeviceConfigurationPolicySCbyName
            #>
            
            [cmdletbinding()]
            
            param
            (
                $name
            )
            
            $graphApiVersion = "beta"
            $Resource = "deviceManagement/configurationPolicies"
            try {

    
                $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$filter=name eq '$name'"
                $SC = (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
            
                }
                catch {}
                $myid = $SC.id
                if ($null -ne $myid) {
                    $fulluri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$myid"
                    $type = "Settings Catalog"
                    }
                    else {
                        $fulluri = ""
                        $type = ""
                    }
                    $output = "" | Select-Object -Property id,fulluri, type    
                    $output.id = $myid
                    $output.fulluri = $fulluri
                    $output.type = $type
                    return $output
                                
}
            
################################################################################################


####################################################
    
Function Get-DeviceProactiveRemediationsbyName(){
    
    <#
    .SYNOPSIS
    This function is used to get device proactive remediations from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any device proactive remediations
    .EXAMPLE
    Get-DeviceProactiveRemediationsbyName
    Returns any device proactive remediations configured in Intune
    .NOTES
    NAME: Get-DeviceProactiveRemediationsbyName
    #>
    
    [cmdletbinding()]
    
    param
    (
        $name
    )
    
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/devicehealthscripts"
    try {

    
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$filter=displayName eq '$name'"
        $PR = (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
        }
        catch {}
        $myid = $PR.id
        if ($null -ne $myid) {
            $fulluri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$myid"
            $type = "Proactive Remediation"
            }
            else {
                $fulluri = ""
                $type = ""
            }
            $output = "" | Select-Object -Property id,fulluri, type    
            $output.id = $myid
            $output.fulluri = $fulluri
            $output.type = $type
            return $output
    
}
    
################################################################################################
    
Function Get-DeviceCompliancePolicybyName(){
    
            <#
            .SYNOPSIS
            This function is used to get device compliance policies from the Graph API REST interface
            .DESCRIPTION
            The function connects to the Graph API Interface and gets any device compliance policies
            .EXAMPLE
            Get-DeviceCompliancePolicybyName
            Returns any device compliance policies configured in Intune
            .NOTES
            NAME: Get-DeviceCompliancePolicybyName
            #>
            
            [cmdletbinding()]
            
            param
            (
                $name
            )
            
            $graphApiVersion = "beta"
            $Resource = "deviceManagement/deviceCompliancePolicies"
            try {

    
                $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$filter=displayName eq '$name'"
                $CP = (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
            
                }
                catch {}
                $myid = $CP.id
                if ($null -ne $myid) {
                    $fulluri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$myid"
                    $type = "Compliance Policy"
                    }
                    else {
                        $fulluri = ""
                        $type = ""
                    }
                    $output = "" | Select-Object -Property id,fulluri, type    
                    $output.id = $myid
                    $output.fulluri = $fulluri
                    $output.type = $type
                    return $output
                                
}

Function Get-DeviceCompliancePolicyScriptsbyName(){
    
    <#
    .SYNOPSIS
    This function is used to get device compliance policy scripts from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any device compliance policies
    .EXAMPLE
    Get-DeviceCompliancePolicyScriptsbyName
    Returns any device compliance policy scripts configured in Intune
    .NOTES
    NAME: Get-DeviceCompliancePolicyScriptsbyName
    #>
    
    [cmdletbinding()]
    
    param
    (
        $name
    )
    
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/deviceComplianceScripts"
    try {


        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$filter=displayName eq '$name'"
        $CP = (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
        }
        catch {}
        $myid = $CP.id
        if ($null -ne $myid) {
            $fulluri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$myid"
            $type = "Compliance Policy Script"
            }
            else {
                $fulluri = ""
                $type = ""
            }
            $output = "" | Select-Object -Property id,fulluri, type    
            $output.id = $myid
            $output.fulluri = $fulluri
            $output.type = $type
            return $output
                        
}
            
#################################################################################################
Function Get-DeviceSecurityPolicybyName(){
    
    <#
    .SYNOPSIS
    This function is used to get device security policies from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any device security policies
    .EXAMPLE
    Get-DeviceSecurityPolicybyName
    Returns any device compliance policies configured in Intune
    .NOTES
    NAME: Get-DeviceSecurityPolicybyName
    #>
    
    [cmdletbinding()]
    
    param
    (
        $name
    )
    
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/intents"
    try {

    
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$filter=displayName eq '$name'"
        $SP = (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
        }
        catch {}
        $myid = $SP.id
        if ($null -ne $myid) {
            $fulluri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$myid"
            $type = "Security Policy"
            }
            else {
                $fulluri = ""
                $type = ""
            }
            $output = "" | Select-Object -Property id,fulluri, type    
            $output.id = $myid
            $output.fulluri = $fulluri
            $output.type = $type
            return $output
    
}

#################################################################################################  

Function Get-ManagedAppProtectionAndroidbyName(){

    <#
    .SYNOPSIS
    This function is used to get managed app protection configuration from the Graph API REST interface Android
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any managed app protection policy Android
    .EXAMPLE
    Get-ManagedAppProtectionAndroidbyName
    .NOTES
    NAME: Get-ManagedAppProtectionAndroidbyName
    #>
    
    param
    (
        $name
    )
    $graphApiVersion = "Beta"
     $Resource = "deviceAppManagement/androidManagedAppProtections"
            try {

    
                $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$filter=displayName eq '$name'"
                $AAP = (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
            
                }
                catch {}
                $myid = $AAP.id
                if ($null -ne $myid) {
                    $fulluri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$myid"
                    $type = "Android App Protection Policy"
                    }
                    else {
                        $fulluri = ""
                        $type = ""
                    }
                    $output = "" | Select-Object -Property id,fulluri, type    
                    $output.id = $myid
                    $output.fulluri = $fulluri
                    $output.type = $type
                    return $output
                        
}

#################################################################################################  

Function Get-ManagedAppProtectionIOSbyName(){

    <#
    .SYNOPSIS
    This function is used to get managed app protection configuration from the Graph API REST interface IOS
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any managed app protection policy IOS
    .EXAMPLE
    Get-ManagedAppProtectionIOSbyName
    .NOTES
    NAME: Get-ManagedAppProtectionIOSbyName
    #>
    param
    (
        $name
    )

    $graphApiVersion = "Beta"
    
                $Resource = "deviceAppManagement/iOSManagedAppProtections"
                try {

    
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$filter=displayName eq '$name'"
                    $IAP = (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
                
                    }
                    catch {}
                    $myid = $IAP.id
                    if ($null -ne $myid) {
                        $fulluri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$myid"
                        $type = "iOS App Protection Policy"
                        }
                        else {
                            $fulluri = ""
                            $type = ""
                        }
                        $output = "" | Select-Object -Property id,fulluri, type    
                        $output.id = $myid
                        $output.fulluri = $fulluri
                        $output.type = $type
                        return $output
                    }
    
Function Get-AutoPilotProfilebyName(){
    
                <#
                .SYNOPSIS
                This function is used to get autopilot profiles from the Graph API REST interface 
                .DESCRIPTION
                The function connects to the Graph API Interface and gets any autopilot profiles
                .EXAMPLE
                Get-AutoPilotProfilebyName
                Returns any autopilot profiles configured in Intune
                .NOTES
                NAME: Get-AutoPilotProfilebyName
                #>
                
                [cmdletbinding()]
                
                param
                (
                    $name
                )
                
                $graphApiVersion = "beta"
                $Resource = "deviceManagement/windowsAutopilotDeploymentProfiles"
                try {

    
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$filter=displayName eq '$name'"
                    $AP = (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
                
                    }
                    catch {}
                    $myid = $AP.id
                    if ($null -ne $myid) {
                        $fulluri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$myid"
                        $type = "Autopilot Profile"
                        }
                        else {
                            $fulluri = ""
                            $type = ""
                        }
                        $output = "" | Select-Object -Property id,fulluri, type    
                        $output.id = $myid
                        $output.fulluri = $fulluri
                        $output.type = $type
                        return $output
                                
}

#################################################################################################

Function Get-AutoPilotESPbyName(){
    
                    <#
                    .SYNOPSIS
                    This function is used to get autopilot ESP from the Graph API REST interface 
                    .DESCRIPTION
                    The function connects to the Graph API Interface and gets any autopilot ESP
                    .EXAMPLE
                    Get-AutoPilotESPbyName
                    Returns any autopilot ESPs configured in Intune
                    .NOTES
                    NAME: Get-AutoPilotESPbyName
                    #>
                    
                    [cmdletbinding()]
                    
                    param
                    (
                        $name
                    )
                    
                    $graphApiVersion = "beta"
                    $Resource = "deviceManagement/deviceEnrollmentConfigurations"
                    try {

    
                        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$filter=displayName eq '$name'"
                        $ESP = (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
                    
                        }
                        catch {}
                        $myid = $ESP.id
                        if ($null -ne $myid) {
                            $fulluri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$myid"
                            $type = "Autopilot ESP"
                            }
                            else {
                                $fulluri = ""
                                $type = ""
                            }
                            $output = "" | Select-Object -Property id,fulluri, type    
                            $output.id = $myid
                            $output.fulluri = $fulluri
                            $output.type = $type
                            return $output
                        }
                
#################################################################################################    


Function Get-DeviceManagementScriptsbyName(){
    
    <#
    .SYNOPSIS
    This function is used to get device PowerShell scripts from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any device scripts
    .EXAMPLE
    Get-DeviceManagementScriptsbyName
    Returns any device management scripts configured in Intune
    .NOTES
    NAME: Get-DeviceManagementScriptsbyName
    #>
    
    [cmdletbinding()]
    
    param
    (
        $name
    )
    
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/devicemanagementscripts"
    try {

    
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$filter=displayName eq '$name'"
        $Script = (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
        }
        catch {}
        $myid = $Script.id
        if ($null -ne $myid) {
            $fulluri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$myid"
            $type = "PowerShell Script"
            }
            else {
                $fulluri = ""
                $type = ""
            }
            $output = "" | Select-Object -Property id,fulluri, type    
            $output.id = $myid
            $output.fulluri = $fulluri
            $output.type = $type
            return $output
    
   
}

Function Get-Win365UserSettingsbyName(){
    
    <#
    .SYNOPSIS
    This function is used to get Windows 365 User Settings Policies from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any device scriptsWindows 365 User Settings Policies
    .EXAMPLE
    Get-Win365UserSettingsbyName
    Returns any Windows 365 User Settings Policies configured in Intune
    .NOTES
    NAME: Get-Win365UserSettingsbyName
    #>
    
    [cmdletbinding()]
    
    param
    (
        $name
    )
    
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/virtualEndpoint/userSettings"
    try {

    
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$filter=displayName eq '$name'"
        $W365User = (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
        }
        catch {}
        $myid = $W365User.id
        if ($null -ne $myid) {
            $fulluri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$myid"
            $type = "Win365 User Settings"
            }
            else {
                $fulluri = ""
                $type = ""
            }
            $output = "" | Select-Object -Property id,fulluri, type    
            $output.id = $myid
            $output.fulluri = $fulluri
            $output.type = $type
            return $output
        
   
}

Function Get-Win365ProvisioningPoliciesbyName(){
    
    <#
    .SYNOPSIS
    This function is used to get Windows 365 Provisioning Policies from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any Windows 365 Provisioning Policies
    .EXAMPLE
    Get-Win365ProvisioningPoliciesbyName
    Returns any Windows 365 Provisioning Policies configured in Intune
    .NOTES
    NAME: Get-Win365ProvisioningPoliciesbyName
    #>
    
    [cmdletbinding()]
    
    param
    (
        $name
    )
    
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/virtualEndpoint/provisioningPolicies"
    try {

    
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$filter=displayName eq '$name'"
        $W365Prov = (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
        }
        catch {}
        $myid = $W365Prov.id
        if ($null -ne $myid) {
            $fulluri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$myid"
            $type = "W365 Provisioning Policy"
            }
            else {
                $fulluri = ""
                $type = ""
            }
            $output = "" | Select-Object -Property id,fulluri, type    
            $output.id = $myid
            $output.fulluri = $fulluri
            $output.type = $type
            return $output
       
}

Function Get-IntunePolicySetsbyName(){
    
    <#
    .SYNOPSIS
    This function is used to get Intune policy sets from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any Intune policy sets
    .EXAMPLE
    Get-IntunePolicySetsbyName
    Returns any policy sets configured in Intune
    .NOTES
    NAME: Get-IntunePolicySetsbyName
    #>
    
    [cmdletbinding()]
    
    param
    (
        $name
    )
    
    $graphApiVersion = "beta"
    $Resource = "deviceAppManagement/policySets"
    try {

    
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$filter=displayName eq '$name'"
        $Policyset = (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
        }
        catch {}
        $myid = $Policyset.id
        if ($null -ne $myid) {
            $fulluri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$myid"
            $type = "Policy Set"
            }
            else {
                $fulluri = ""
                $type = ""
            }
            $output = "" | Select-Object -Property id,fulluri, type    
            $output.id = $myid
            $output.fulluri = $fulluri
            $output.type = $type
            return $output
       
}

Function Get-EnrollmentConfigurationsbyName(){
    
    <#
    .SYNOPSIS
    This function is used to get Intune enrollment configurations from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any Intune enrollment configurations
    .EXAMPLE
    Get-EnrollmentConfigurationsbyName
    Returns any enrollment configurations configured in Intune
    .NOTES
    NAME: Get-EnrollmentConfigurationsbyName
    #>
    
    [cmdletbinding()]
    
    param
    (
        $name
    )
    
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/deviceEnrollmentConfigurations"
    try {

    
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$filter=displayName eq '$name'"
        $EC = (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
        }
        catch {}
        $myid = $EC.id
        if ($null -ne $myid) {
            $fulluri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$myid"
            $type = "Enrollment Configuration"
            }
            else {
                $fulluri = ""
                $type = ""
            }
            $output = "" | Select-Object -Property id,fulluri, type    
            $output.id = $myid
            $output.fulluri = $fulluri
            $output.type = $type
            return $output
          
}
    

Function Get-DeviceCategoriesbyName(){
    
    <#
    .SYNOPSIS
    This function is used to get Intune device categories from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any Intune device categories
    .EXAMPLE
    Get-DeviceCategoriesbyName
    Returns any device categories configured in Intune
    .NOTES
    NAME: Get-DeviceCategoriesbyName
    #>
    
    [cmdletbinding()]
    
    param
    (
        $name
    )
    
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/deviceCategories"
    try {

    
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$filter=displayName eq '$name'"
        $DC = (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
        }
        catch {}
        $myid = $DC.id
        if ($null -ne $myid) {
            $fulluri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$myid"
            $type = "Device Category"
            }
            else {
                $fulluri = ""
                $type = ""
            }
            $output = "" | Select-Object -Property id,fulluri, type    
            $output.id = $myid
            $output.fulluri = $fulluri
            $output.type = $type
            return $output
    }


Function Get-DeviceFiltersbyName(){
    
    <#
    .SYNOPSIS
    This function is used to get Intune device filters from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any Intune device filters
    .EXAMPLE
    Get-DeviceFiltersbyName
    Returns any device filters configured in Intune
    .NOTES
    NAME: Get-DeviceFiltersbyName
    #>
    
    [cmdletbinding()]
    
    param
    (
        $name
    )
    
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/assignmentFilters"
    try {

    
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$filter=displayName eq '$name'"
        $DF = (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
        }
        catch {}
        $myid = $DF.id
        if ($null -ne $myid) {
            $fulluri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$myid"
            $type = "Device Filter"
            }
            else {
                $fulluri = ""
                $type = ""
            }
            $output = "" | Select-Object -Property id,fulluri, type    
            $output.id = $myid
            $output.fulluri = $fulluri
            $output.type = $type
            return $output
    }


Function Get-BrandingProfilesbyName(){
    
    <#
    .SYNOPSIS
    This function is used to get Intune Branding Profiles from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any Intune Branding Profiles
    .EXAMPLE
    Get-BrandingProfilesbyName
    Returns any Branding Profiles configured in Intune
    .NOTES
    NAME: Get-BrandingProfilesbyName
    #>
    
    [cmdletbinding()]
    
    param
    (
        $name
    )
    
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/intuneBrandingProfiles"
    try {

    
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$filter=displayName eq '$name'"
        $BP = (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
        }
        catch {}
        $myid = $BP.id
        if ($null -ne $myid) {
            $fulluri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$myid"
            $type = "Branding Profile"
            }
            else {
                $fulluri = ""
                $type = ""
            }
            $output = "" | Select-Object -Property id,fulluri, type    
            $output.id = $myid
            $output.fulluri = $fulluri
            $output.type = $type
            return $output
        
   
}


Function Get-AdminApprovalsbyName(){
    
    <#
    .SYNOPSIS
    This function is used to get Intune admin approvals from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any Intune admin approvals
    .EXAMPLE
    Get-AdminApprovalsbyName
    Returns any admin approvals configured in Intune
    .NOTES
    NAME: Get-AdminApprovalsbyName
    #>
    
    [cmdletbinding()]
    
    param
    (
        $name
    )
    
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/operationApprovalPolicies"
    try {

    
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$filter=displayName eq '$name'"
        $AdminAp = (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
        }
        catch {}
        $myid = $AdminAp.id
        if ($null -ne $myid) {
            $fulluri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$myid"
            $type = "Admin Approval"
            }
            else {
                $fulluri = ""
                $type = ""
            }
            $output = "" | Select-Object -Property id,fulluri, type    
            $output.id = $myid
            $output.fulluri = $fulluri
            $output.type = $type
            return $output
       
}

Function Get-OrgMessagesbyName(){
    
    <#
    .SYNOPSIS
    This function is used to get Intune organizational messages from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any Intune organizational messages
    .EXAMPLE
    Get-OrgMessagesbyName
    Returns any organizational messages configured in Intune
    .NOTES
    NAME: Get-OrgMessagesbyName
    #>
    
    [cmdletbinding()]
    
    param
    (
        $name
    )
    
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/organizationalMessageDetails"
    try {

    
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$filter=displayName eq '$name'"
        $OM = (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
        }
        catch {}
        $myid = $OM.id
        if ($null -ne $myid) {
            $fulluri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$myid"
            $type = "Organization Message"
            }
            else {
                $fulluri = ""
                $type = ""
            }
            $output = "" | Select-Object -Property id,fulluri, type    
            $output.id = $myid
            $output.fulluri = $fulluri
            $output.type = $type
            return $output
       
}


Function Get-IntuneTermsbyName(){
    
    <#
    .SYNOPSIS
    This function is used to get Intune terms and conditions from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any Intune terms and conditions
    .EXAMPLE
    Get-IntuneTermsbyName
    Returns any terms and conditions configured in Intune
    .NOTES
    NAME: Get-IntuneTermsbyName
    #>
    
    [cmdletbinding()]
    
    param
    (
        $name
    )
    
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/termsAndConditions"
    try {

    
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$filter=displayName eq '$name'"
        $Terms = (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
        }
        catch {}
        $myid = $Terms.id
        if ($null -ne $myid) {
            $fulluri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$myid"
            $type = "Terms and Conditions"
            }
            else {
                $fulluri = ""
                $type = ""
            }
            $output = "" | Select-Object -Property id,fulluri, type    
            $output.id = $myid
            $output.fulluri = $fulluri
            $output.type = $type
            return $output
        
   
}

Function Get-IntuneRolesbyName(){
    
    <#
    .SYNOPSIS
    This function is used to get Intune custom roles from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any Intune custom roles
    .EXAMPLE
    Get-IntuneRolesbyName
    Returns any custom roles configured in Intune
    .NOTES
    NAME: Get-IntuneRolesbyName
    #>
    
    [cmdletbinding()]
    
    param
    (
        $name
    )
    
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/roleDefinitions"
    try {

    
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$filter=displayName eq '$name'"
        $Roles = (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
        }
        catch {}
        $myid = $Roles.id
        if ($null -ne $myid) {
            $fulluri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$myid"
            $type = "Custom Role"
            }
            else {
                $fulluri = ""
                $type = ""
            }
            $output = "" | Select-Object -Property id,fulluri, type    
            $output.id = $myid
            $output.fulluri = $fulluri
            $output.type = $type
            return $output
        
   
}
################################################################################################
####################################################
Function Get-GraphAADGroupsbyName(){
    
    <#
    .SYNOPSIS
    This function is used to get AAD Groups from the Graph API REST interface 
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any AAD Groups
    .EXAMPLE
    Get-GraphAADGroupsbyName
    Returns any AAD Groups
    .NOTES
    NAME: Get-GraphAADGroupsbyName
    #>
    
    [cmdletbinding()]
    
    param
    (
        $name
    )
    
    $graphApiVersion = "beta"
    $Resource = "Groups"
    try {

    
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$filter=displayName eq '$name'"
        $AAD = (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
        }
        catch {}
        $myid = $AAD.id
        if ($null -ne $myid) {
            $fulluri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$myid"
            $type = "AAD Group"
            }
            else {
                $fulluri = ""
                $type = ""
            }
            $output = "" | Select-Object -Property id,fulluri, type    
            $output.id = $myid
            $output.fulluri = $fulluri
            $output.type = $type
            return $output
        
}

#################################################################################################  
function Get-DetailsbyName () {
    <#
    .SYNOPSIS
    This function is used to get  ID and URI from only the name
    .DESCRIPTION
    This function is used to get  ID and URI from only the name
    .EXAMPLE
    Get-DetailsbyName
    Returns ID and full URI
    .NOTES
    NAME: Get-DetailsbyName
    #>
    
    [cmdletbinding()]
    
    param
    (
        $name
    )

    $id = ""
    while ($id -eq "") {
$check = Get-DeviceConfigurationPolicybyName -name $name
if ($null -ne $check.id) {
    $id = $check.id
    $uri = $check.fulluri
    $type = $check.type
    break
}
$check = Get-DeviceConfigurationPolicySCbyName -name $name
if ($null -ne $check.id) {
    $id = $check.id
    $uri = $check.fulluri
    $type = $check.type
    break
}
$check = Get-DeviceCompliancePolicybyName -name $name
if ($null -ne $check.id) {
    $id = $check.id
    $uri = $check.fulluri
    $type = $check.type
    break
}
$check = Get-DeviceCompliancePolicyscriptsbyName -name $name
if ($null -ne $check.id) {
    $id = $check.id
    $uri = $check.fulluri
    $type = $check.type
    break
}
$check = Get-DeviceSecurityPolicybyName -name $name
if ($null -ne $check.id) {
    $id = $check.id
    $uri = $check.fulluri
    $type = $check.type
    break
}
$check = Get-AutoPilotProfilebyName -name $name
if ($null -ne $check.id) {
    $id = $check.id
    $uri = $check.fulluri
    $type = $check.type
    break
}
$check = Get-AutoPilotESPbyName -name $name
if ($null -ne $check.id) {
    $id = $check.id
    $uri = $check.fulluri
    $type = $check.type
    break
}
$check = Get-ManagedAppProtectionAndroidbyName -name $name
if ($null -ne $check.id) {
    $id = $check.id
    $uri = $check.fulluri
    $type = $check.type
    break
}
$check = Get-ManagedAppProtectioniosbyName -name $name
if ($null -ne $check.id) {
    $id = $check.id
    $uri = $check.fulluri
    $type = $check.type
    break
}
$check = Get-DeviceConfigurationPolicyGPbyName -name $name
if ($null -ne $check.id) {
    $id = $check.id
    $uri = $check.fulluri
    $type = $check.type
    break
}
$check = Get-ConditionalAccessPolicybyName -name $name
if ($null -ne $check.id) {
    $id = $check.id
    $uri = $check.fulluri
    $type = $check.type
    break
}
$check = Get-DeviceProactiveRemediationsbyName -name $name
if ($null -ne $check.id) {
    $id = $check.id
    $uri = $check.fulluri
    $type = $check.type
    break
}
$check = Get-GraphAADGroupsbyName -name $name
if ($null -ne $check.id) {
    $id = $check.id
    $uri = $check.fulluri
    $type = $check.type
    break
}
$check = Get-IntuneApplicationbyName -name $name
if ($null -ne $check.id) {
    $id = $check.id
    $uri = $check.fulluri
    $type = $check.type
    break
}
$check = Get-DeviceManagementScriptsbyName -name $name
if ($null -ne $check.id) {
    $id = $check.id
    $uri = $check.fulluri
    $type = $check.type
    break
}
$check = Get-Win365UserSettingsbyName -name $name
if ($null -ne $check.id) {
    $id = $check.id
    $uri = $check.fulluri
    $type = $check.type
    break
}
$check = Get-Win365ProvisioningPoliciesbyName -name $name
if ($null -ne $check.id) {
    $id = $check.id
    $uri = $check.fulluri
    $type = $check.type
    break
}
$check = Get-IntunePolicySetsbyName -name $name
if ($null -ne $check.id) {
    $id = $check.id
    $uri = $check.fulluri
    $type = $check.type
    break
}
$check = Get-EnrollmentConfigurationsbyName -name $name
if ($null -ne $check.id) {
    $id = $check.id
    $uri = $check.fulluri
    $type = $check.type
    break
}
$check = Get-DeviceCategoriesbyName -name $name
if ($null -ne $check.id) {
    $id = $check.id
    $uri = $check.fulluri
    $type = $check.type
    break
}
$check = Get-DeviceFiltersbyName -name $name
if ($null -ne $check.id) {
    $id = $check.id
    $uri = $check.fulluri
    $type = $check.type
    break
}
$check = Get-BrandingProfilesbyName -name $name
if ($null -ne $check.id) {
    $id = $check.id
    $uri = $check.fulluri
    $type = $check.type
    break
}
$check = Get-AdminApprovalsbyName -name $name
if ($null -ne $check.id) {
    $id = $check.id
    $uri = $check.fulluri
    $type = $check.type
    break
}
#$orgmessages = Get-OrgMessages -id $id
$check = Get-IntuneTermsbyName -name $name
if ($null -ne $check.id) {
    $id = $check.id
    $uri = $check.fulluri
    $type = $check.type
    break
}
$check = Get-IntuneRolesbyName -name $name
if ($null -ne $check.id) {
    $id = $check.id
    $uri = $check.fulluri
    $type = $check.type
    break
}
    }
    $output = "" | Select-Object -Property id,uri, type    
        $output.id = $id
        $output.uri = $uri
        $output.type = $type
        return $output
}

#################################################################################################
function getpolicyjson() {
        <#
    .SYNOPSIS
    This function is used to add a new device policy by copying an existing policy, manipulating the JSON and then adding via Graph
    .DESCRIPTION
    The function grabs an existing policy, decrypts if requires, renames, removes any GUIDs and then returns the JSON
    .EXAMPLE
    getpolicyjson -policy $policy -name $name
    .NOTES
    NAME: getpolicyjson
    #>

    param
    (
        $resource,
        $policyid
    )
    $id = $policyid
    write-host $resource
    $graphApiVersion = "beta"
    switch ($resource) {
    "deviceManagement/deviceConfigurations" {
     $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
     $policy = Get-DecryptedDeviceConfigurationPolicy -dcpid $id
     $oldname = $policy.displayName
     $newname = "Copy Of " + $oldname
     $policy.displayName = $newname

     ##Custom settings only for OMA-URI
             ##Remove settings which break Custom OMA-URI
        
             $policyconvert = $policy.omaSettings
             if ($null -ne $policyconvert) {
             $policyconvert = $policyconvert | Select-Object -Property * -ExcludeProperty isEncrypted, secretReferenceValueId
             foreach ($pvalue in $policyconvert) {
             $unencoded = $pvalue.value
             $EncodedText =[Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($unencoded))
                $pvalue.value = $EncodedText
             }
             $policy.omaSettings = $policyconvert

            }
         # Set SupportsScopeTags to $false, because $true currently returns an HTTP Status 400 Bad Request error.
    if ($policy.supportsScopeTags) {
        $policy.supportsScopeTags = $false
    }



        $policy.PSObject.Properties | Foreach-Object {
            if ($null -ne $_.Value) {
                if ($_.Value.GetType().Name -eq "DateTime") {
                    $_.Value = (Get-Date -Date $_.Value -Format s) + "Z"
                }
                if ($_.Value.GetType().Name -eq "isEncrypted") {
                    $_.Value = "false"
                }
            }
        }


    }

    "deviceManagement/groupPolicyConfigurations" {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $policy = Get-DeviceConfigurationPolicyGP -id $id
        $oldname = $policy.DisplayName
        $newname = "Copy Of " + $oldname
        $policy.displayName = $newname
            # Set SupportsScopeTags to $false, because $true currently returns an HTTP Status 400 Bad Request error.
       if ($policy.supportsScopeTags) {
           $policy.supportsScopeTags = $false
       }
   
           $policy.PSObject.Properties | Foreach-Object {
               if ($null -ne $_.Value) {
                   if ($_.Value.GetType().Name -eq "DateTime") {
                       $_.Value = (Get-Date -Date $_.Value -Format s) + "Z"
                   }
               }
           }
       }

    "deviceManagement/devicehealthscripts" {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $policy = Get-DeviceProactiveRemediations -id $id
        $oldname = $policy.DisplayName
        $newname = "Copy Of " + $oldname
        $policy.displayName = $newname
            # Set SupportsScopeTags to $false, because $true currently returns an HTTP Status 400 Bad Request error.
       if ($policy.supportsScopeTags) {
           $policy.supportsScopeTags = $false
       }
   
           $policy.PSObject.Properties | Foreach-Object {
               if ($null -ne $_.Value) {
                   if ($_.Value.GetType().Name -eq "DateTime") {
                       $_.Value = (Get-Date -Date $_.Value -Format s) + "Z"
                   }
               }
           }
       }

       "deviceManagement/devicemanagementscripts" {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $policy = Get-DeviceManagementScripts -id $id
        $oldname = $policy.DisplayName
        $newname = "Copy of " + $oldname
        $policy.displayName = $newname
            # Set SupportsScopeTags to $false, because $true currently returns an HTTP Status 400 Bad Request error.
       if ($policy.supportsScopeTags) {
           $policy.supportsScopeTags = $false
       }
   
           $policy.PSObject.Properties | Foreach-Object {
               if ($null -ne $_.Value) {
                   if ($_.Value.GetType().Name -eq "DateTime") {
                       $_.Value = (Get-Date -Date $_.Value -Format s) + "Z"
                   }
               }
           }
       }
       "deviceManagement/deviceComplianceScripts" {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $policy = Get-DeviceCompliancePolicyScripts -id $id
        $oldname = $policy.displayName
        if ($changename -eq "yes") {
            $newname = "Copy of " + $oldname
        }
        else {
            $newname = $oldname
        }        $policy.displayName = $newname
            # Set SupportsScopeTags to $false, because $true currently returns an HTTP Status 400 Bad Request error.
       if ($policy.supportsScopeTags) {
           $policy.supportsScopeTags = $false
       }
   
           $policy.PSObject.Properties | Foreach-Object {
               if ($null -ne $_.Value) {
                   if ($_.Value.GetType().Name -eq "DateTime") {
                       $_.Value = (Get-Date -Date $_.Value -Format s) + "Z"
                   }
               }
           }
       }

    "deviceManagement/configurationPolicies" {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $policy = Get-DeviceConfigurationPolicysc -id $id
        $policy | Add-Member -MemberType NoteProperty -Name 'settings' -Value @() -Force
        #$settings = Invoke-MSGraphRequest -HttpMethod GET -Url "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$id/settings" | Get-MSGraphAllPages
        $settings = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$id/settings" -OutputType PSObject
        $settings = $settings.value
        $policynextlink = $settings."@odata.nextlink"
        $policynextlink = $policynextlink -replace '\S', ''
        while (($policynextlink -ne "") -and ($null -ne $policynextlink))
        {
            $nextsettings = (Invoke-MgGraphRequest -Uri $policynextlink -Method Gconneet -OutputType PSObject)
            $policynextlink = $nextsettings."@odata.nextLink"
            $policynextlink = $policynextlink -replace '\S', ''
            $settings += $nextsettings.value
        }

        $settings =  $settings | select-object * -ExcludeProperty '@odata.count'
        if ($settings -isnot [System.Array]) {
            $policy.Settings = @($settings)
        } else {
            $policy.Settings = $settings
        }
        
        #
        $oldname = $policy.Name
        $newname = "Copy Of " + $oldname
        $policy.Name = $newname

    }
    
    "deviceManagement/deviceCompliancePolicies" {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $policy = Get-DeviceCompliancePolicy -id $id
        $oldname = $policy.DisplayName
        $newname = "Copy Of " + $oldname
        $policy.DisplayName = $newname
        
            $scheduledActionsForRule = @(
                @{
                    ruleName = "PasswordRequired"
                    scheduledActionConfigurations = @(
                        @{
                            actionType = "block"
                            gracePeriodHours = 0
                            notificationTemplateId = ""
                        }
                    )
                }
            )
            $policy | Add-Member -NotePropertyName scheduledActionsForRule -NotePropertyValue $scheduledActionsForRule
            
            
    }
    "deviceManagement/intents" {
        $policy = Get-DeviceSecurityPolicy -id $id
        $templateid = $policy.templateID
        $uri = "https://graph.microsoft.com/beta/deviceManagement/templates/$templateId/createInstance"
        #$template = Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceManagement/templates/$templateid" -Headers $authToken -Method Get
        $template = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/templates/$templateid" -OutputType PSObject
        $template = $template
        $templateCategories = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/templates/$templateid/categories" -OutputType PSObject).Value
        #$intentSettingsDelta = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceManagement/intents/$id/categories/$($templateCategory.id)/settings" -Headers $authToken -Method Get).value
        $intentSettingsDelta = @()
        foreach ($templateCategory in $templateCategories) {
            # Get all configured values for the template categories
            Write-Verbose "Requesting Intent Setting Values"
            $intentSettingsDelta += (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/intents/$($policy.id)/categories/$($templateCategory.id)/settings").value
        }
        $oldname = $policy.displayName
        $newname = "Copy Of " + $oldname
        $policy = @{
            "displayName" = $newname
            "description" = $policy.description
            "settingsDelta" = $intentSettingsDelta
            "roleScopeTagIds" = $policy.roleScopeTagIds
        }
        $policy | Add-Member -NotePropertyName displayName -NotePropertyValue $newname



    }
    "deviceManagement/windowsAutopilotDeploymentProfiles" {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $policy = Get-AutoPilotProfile -id $id
        $oldname = $policy.displayName
        $newname = "Copy Of " + $oldname
        $policy.displayName = $newname
    }
    "groups" {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $policy = Get-GraphAADGroups -id $id
        $oldname = $policy.displayName
        $newname = "Copy Of " + $oldname
        $policy.displayName = $newname
        $policy = $policy | Select-Object description, DisplayName, groupTypes, mailEnabled, mailNickname, securityEnabled, isAssignabletoRole, membershiprule, MembershipRuleProcessingState
    }
    "deviceManagement/deviceEnrollmentConfigurations" {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $policy = Get-AutoPilotESP -id $id
        $oldname = $policy.displayName
        $newname = "Copy Of " + $oldname
        $policy.displayName = $newname
    }
    "deviceManagement/virtualEndpoint/userSettings" {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $policy = Get-Win365UserSettings -id $id
        $oldname = $policy.displayName
        $newname = "Copy Of " + $oldname
        $policy.displayName = $newname
    }
    "deviceManagement/virtualEndpoint/provisioningPolicies" {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $policy = Get-Win365ProvisioningPolicies -id $id
        $oldname = $policy.displayName
        $newname = "Copy Of " + $oldname
        $policy.displayName = $newname
    }
    "deviceAppManagement/managedAppPoliciesandroid" {
        $uri = "https://graph.microsoft.com/$graphApiVersion/deviceAppManagement/managedAppPolicies"
        #$policy = Invoke-RestMethod -Uri "https://graph.microsoft.com/$graphApiVersion/deviceAppManagement/managedAppPolicies('$id')" -Headers $authToken -Method Get
        $policy = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/$graphApiVersion/deviceAppManagement/managedAppPolicies('$id')" -OutputType PSObject
        $oldname = $policy.displayName
        $newname = "Copy Of " + $oldname
        $policy.displayName = $newname
         # Set SupportsScopeTags to $false, because $true currently returns an HTTP Status 400 Bad Request error.
         if ($policy.supportsScopeTags) {
            $policy.supportsScopeTags = $false
        }
    
            $policy.PSObject.Properties | Foreach-Object {
                if ($null -ne $_.Value) {
                    if ($_.Value.GetType().Name -eq "DateTime") {
                        $_.Value = (Get-Date -Date $_.Value -Format s) + "Z"
                    }
                }
            }


    }
    "deviceAppManagement/managedAppPoliciesios" {
        $uri = "https://graph.microsoft.com/$graphApiVersion/deviceAppManagement/managedAppPolicies"
        #$policy = Invoke-RestMethod -Uri "https://graph.microsoft.com/$graphApiVersion/deviceAppManagement/managedAppPolicies('$id')" -Headers $authToken -Method Get
        $policy = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/$graphApiVersion/deviceAppManagement/managedAppPolicies('$id')" -OutputType PSObject
        $oldname = $policy.displayName
        $newname = "Copy Of " + $oldname
        $policy.displayName = $newname
         # Set SupportsScopeTags to $false, because $true currently returns an HTTP Status 400 Bad Request error.
         if ($policy.supportsScopeTags) {
            $policy.supportsScopeTags = $false
        }
    
            $policy.PSObject.Properties | Foreach-Object {
                if ($null -ne $_.Value) {
                    if ($_.Value.GetType().Name -eq "DateTime") {
                        $_.Value = (Get-Date -Date $_.Value -Format s) + "Z"
                    }
                }
            }


    }

    "conditionalaccess" {
        $uri = "conditionalaccess"
        $policy = Get-ConditionalAccessPolicy -id $id
    }
    "deviceAppManagement/mobileApps" {
        $uri = "https://graph.microsoft.com/$graphApiVersion/deviceAppManagement/mobileApps"
        $policy = Get-IntuneApplication -id $id
        $oldname = $policy.displayName
        $newname = "Copy of " + $oldname
        $policy.displayName = $newname
        $policy = $policy | Select-Object * -ExcludeProperty uploadState, publishingState, isAssigned, dependentAppCount, supersedingAppCount, supersededAppCount
    }
    "deviceAppManagement/policySets" {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $policy = Get-IntunePolicySets -id $id
        $oldname = $policy.displayName
        $newname = "Copy Of " + $oldname
        $policy.displayName = $newname
        $policyitems = $policy.items | select-object * -ExcludeProperty createdDateTime, lastModifiedDateTime, id, itemType, displayName, status, errorcode, priority, targetedAppManagementLevels
        $policy.items = $policyitems
        $policy = $policy | Select-Object * -ExcludeProperty '@odata.context', status, errorcode, 'items@odata.context'
    }
    "deviceManagement/deviceEnrollmentConfigurations" {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $policy = Get-EnrollmentConfigurations -id $id
        $oldname = $policy.displayName
        $newname = "Copy Of " + $oldname
        $policy.displayName = $newname
    }
    "deviceManagement/deviceCategories" {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $policy = Get-DeviceCategories -id $id
        $oldname = $policy.displayName
        $newname = "Copy Of " + $oldname
        $policy.displayName = $newname
    }
    "deviceManagement/assignmentFilters" {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $policy = Get-DeviceFilters -id $id
        $oldname = $policy.displayName
        $newname = "Copy Of " + $oldname
        $policy.displayName = $newname
        $policy = $policy | Select-Object * -ExcludeProperty Payloads
    }
    "deviceManagement/intuneBrandingProfiles" {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $policy = Get-BrandingProfiles -id $id
        $oldname = $policy.profileName
        $newname = "Copy Of " + $oldname
        $policy.profileName = $newname
    }
    "deviceManagement/operationApprovalPolicies" {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $policy = Get-AdminApprovals -id $id
        $oldname = $policy.displayName
        $newname = "Copy Of " + $oldname
        $policy.displayName = $newname
    }
    "deviceManagement/organizationalMessageDetails" {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $policy = Get-OrgMessages -id $id
        $oldname = $policy.displayName
        $newname = "Copy Of " + $oldname
        $policy.displayName = $newname
    }
    "deviceManagement/termsAndConditions" {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $policy = Get-IntuneTerms -id $id
        $oldname = $policy.displayName
        $newname = "Copy Of " + $oldname
        $policy.displayName = $newname
        $policy = $policy | Select-Object * -ExcludeProperty modifiedDateTime
    }
    "deviceManagement/roleDefinitions" {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $policy = Get-IntuneRoles -id $id
        $oldname = $policy.displayName
        $newname = "Copy Of " + $oldname
        $policy.displayName = $newname
    }
    }

    ##We don't want to convert CA policy to JSON
    if (($resource -eq "conditionalaccess")) {
        $policy = $policy
    }
    else {
    # Remove any GUIDs or dates/times to allow Intune to regenerate
    if ($resource -eq "deviceManagement/termsAndConditions") {
        ##We need the version number for T&Cs
        $policy = $policy | Select-Object * -ExcludeProperty id, createdDateTime, LastmodifieddateTime, creationSource, '@odata.count' | ConvertTo-Json -Depth 100
    
        }
        else {
        $policy = $policy | Select-Object * -ExcludeProperty id, createdDateTime, LastmodifieddateTime, version, creationSource, '@odata.count' | ConvertTo-Json -Depth 100
        }
        }

    return $policy, $uri

}





###############################################################################################################
######                                          MS Graph Implementations                                 ######
###############################################################################################################
if ($automated -eq "yes") {
 
    $body = @{
        grant_type="client_credentials";
        client_id=$clientId;
        client_secret=$clientSecret;
        scope="https://graph.microsoft.com/.default";
    }
     
    $response = Invoke-RestMethod -Method Post -Uri https://login.microsoftonline.com/$sourcetenant/oauth2/v2.0/token -Body $body
    $accessToken = $response.access_token
     

    Select-MgProfile -Name Beta
Connect-MgGraph  -AccessToken $accessToken 
write-host "Graph Connection Established"
}
else {
##Connect to Graph
Select-MgProfile -Name Beta
Connect-MgGraph -Scopes Policy.ReadWrite.ConditionalAccess, CloudPC.ReadWrite.All, DeviceManagementServiceConfig.ReadWrite.All, RoleAssignmentSchedule.ReadWrite.Directory, Domain.Read.All, Domain.ReadWrite.All, Directory.Read.All, Policy.ReadWrite.ConditionalAccess, DeviceManagementApps.ReadWrite.All, DeviceManagementConfiguration.ReadWrite.All, DeviceManagementManagedDevices.ReadWrite.All, openid, profile, email, offline_access, DeviceManagementRBAC.Read.All, DeviceManagementRBAC.ReadWrite.All
}


###############################################################################################################
######                                          Grab the Profiles                                        ######
###############################################################################################################
$profiles = @()
$configuration = @()

##Check if any parameters have been passed
if (($namecheck -ne $true) -and ($idcheck -ne $true)) {
write-host "No parameters passed, grabbing all profiles"

##Get Config Policies
$configuration += Get-DeviceConfigurationPolicy | Select-Object ID, DisplayName, Description, @{N='Type';E={"Config Policy"}}

##Get Admin Template Policies
$configuration += Get-DeviceConfigurationPolicyGP | Select-Object ID, DisplayName, Description, @{N='Type';E={"Admin Template"}}


##Get Settings Catalog Policies
$configuration += Get-DeviceConfigurationPolicySC | Select-Object @{N='ID';E={$_.id}}, @{N='DisplayName';E={$_.Name}}, @{N='Description';E={$_.Description}} , @{N='Type';E={"Settings Catalog"}}

##Get Compliance Policies
$configuration += Get-DeviceCompliancePolicy | Select-Object ID, DisplayName, Description, @{N='Type';E={"Compliance Policy"}}

##Get Proactive Remediations
$configuration += Get-DeviceProactiveRemediations | Select-Object ID, DisplayName, Description, @{N='Type';E={"Proactive Remediation"}}

##Get Device Scripts
$configuration += Get-DeviceManagementScripts | Select-Object ID, DisplayName, Description, @{N='Type';E={"PowerShell Script"}}

##Get Compliance Scripts
$configuration += Get-DeviceCompliancePolicyScripts | Select-Object ID, DisplayName, Description, @{N='Type';E={"Compliance Script"}}

##Get Security Policies
$configuration += Get-DeviceSecurityPolicy | Select-Object ID, DisplayName, Description, @{N='Type';E={"Security Policy"}}

##Get Autopilot Profiles
$configuration += Get-AutoPilotProfile | Select-Object ID, DisplayName, Description, @{N='Type';E={"Autopilot Profile"}}

##Get AAD Groups
$configuration += Get-GraphAADGroups | Select-Object ID, DisplayName, Description, @{N='Type';E={"AAD Group"}}

##Get Autopilot ESP
$configuration += Get-AutoPilotESP | Select-Object ID, DisplayName, Description, @{N='Type';E={"Autopilot ESP"}}

##Get App Protection Policies
#Android
$androidapp = Get-ManagedAppProtectionAndroid | Select-Object -expandproperty Value
$configuration += $androidapp | Select-Object ID, DisplayName, Description, @{N='Type';E={"Android App Protection"}}
#IOS
$iosapp = Get-ManagedAppProtectionios | Select-Object -expandproperty Value
$configuration += $iosapp | Select-Object ID, DisplayName, Description, @{N='Type';E={"iOS App Protection"}}

##Get Conditional Access Policies
$configuration += Get-ConditionalAccessPolicy | Select-Object ID, DisplayName, @{N='Type';E={"Conditional Access Policy"}}

##Get Winget Apps
$configuration += Get-IntuneApplication | Select-Object ID, DisplayName, Description, @{N='Type';E={"Winget Application"}}

##Get Win365 User Settings
$configuration += Get-Win365UserSettings | Select-Object ID, DisplayName, Description,  @{N='Type';E={"Win365 User Settings"}}

##Get Win365 Provisioning Policies
$configuration += Get-Win365ProvisioningPolicies | Select-Object ID, DisplayName, Description,  @{N='Type';E={"Win365 Provisioning Policy"}}


##Get Intune Policy Sets
$configuration += Get-IntunePolicySets | Select-Object ID, DisplayName, Description,  @{N='Type';E={"Policy Set"}}

##Get Enrollment Configurations
$configuration += Get-EnrollmentConfigurations | Select-Object ID, DisplayName, Description,  @{N='Type';E={"Enrollment Configuration"}}

##Get Device Categories
$configuration += Get-DeviceCategories | Select-Object ID, DisplayName, Description,  @{N='Type';E={"Device Categories"}}

##Get Device Filters
$configuration += Get-DeviceFilters | Select-Object ID, DisplayName, Description,  @{N='Type';E={"Device Filter"}}

##Get Branding Profiles
$configuration += Get-BrandingProfiles | Select-Object ID,  @{N='DisplayName';E={$_.profileName}}, Description,  @{N='Type';E={"Branding Profile"}}

##Get Admin Approvals
$configuration += Get-AdminApprovals | Select-Object ID, DisplayName, Description,  @{N='Type';E={"Admin Approval"}}

##Get Org Messages
#Note API NOT LIVE YET
#$configuration += Get-OrgMessages | Select-Object ID, DisplayName, Description,  @{N='Type';E={"Organization Message"}}

##Get Intune Terms
$configuration += Get-IntuneTerms | Select-Object ID, DisplayName, Description,  @{N='Type';E={"Intune Terms"}}

##Get Intune Roles
$configuration += Get-IntuneRoles | Select-Object ID, DisplayName, Description,  @{N='Type';E={"Intune Role"}}

##Check if everything set in parameters
if ($everythingcheck -ne $true) {
##Display the list of policies
write-host "No parameters detected, displaying UI"
$configuration2 = $configuration | Out-GridView -PassThru -Title "Select policies to copy"
}
else {
    ##Grab all policies
    write-host "Grabbing everything"
    $configuration2 = $configuration
}

}
else {
$configuration2 = @()
    ##Parameters passed, check what they are
    if ($namecheck -eq $true) {
        ##Name(s) sent, convert to ID and pass-through
        foreach ($item in $name) {
            write-host "Getting ID for $name"
            $policyid = (Get-DetailsbyName -name $item)
            $id = $policyid.ID
            write-host "ID is $id"
            $configuration2 += $policyid
        }
    }
    if ($idcheck -eq $true) {
        ##ID(s) sent, pass-through
        foreach ($item in $inputid) {
            write-host "Copying policy $id"
            $object = "" | select-object id
            $object.id = $item
            $configuration2 += $object
        }

    }
}
$configuration2 | ForEach-Object {

##Find out what it is
$id = $_.ID
write-host $id

##Performance improvement, use existing array instead of additional graph calls
if (($namecheck -ne $true) -and ($idcheck -ne $true)) {
$policy = $configuration | where-object {($_.ID -eq $id) -and ($_.Type -eq "Config Policy")}
$catalog = $configuration | where-object {($_.ID -eq $id) -and ($_.Type -eq "Settings Catalog")}
$compliance = $configuration | where-object {($_.ID -eq $id) -and ($_.Type -eq "Compliance Policy")}
$security = $configuration | where-object {($_.ID -eq $id) -and ($_.Type -eq "Security Policy")}
$autopilot = $configuration | where-object {($_.ID -eq $id) -and ($_.Type -eq "Autopilot Profile")}
$esp = $configuration | where-object {($_.ID -eq $id) -and ($_.Type -eq "Autopilot ESP")}
$android = $configuration | where-object {($_.ID -eq $id) -and ($_.Type -eq "Android App Protection")}
$ios = $configuration | where-object {($_.ID -eq $id) -and ($_.Type -eq "iOS App Protection")}
$gp = $configuration | where-object {($_.ID -eq $id) -and ($_.Type -eq "Admin Template")}
$ca = $configuration | where-object {($_.ID -eq $id) -and ($_.Type -eq "Conditional Access Policy")}
$proac = $configuration | where-object {($_.ID -eq $id) -and ($_.Type -eq "Proactive Remediation")}
$aad = $configuration | where-object {($_.ID -eq $id) -and ($_.Type -eq "AAD Group")}
$wingetapp = $configuration | where-object {($_.ID -eq $id) -and ($_.Type -eq "Winget Application")}
$scripts = $configuration | where-object {($_.ID -eq $id) -and ($_.Type -eq "PowerShell Script")}
$compliancescripts = $configuration | where-object {($_.ID -eq $id) -and ($_.Type -eq "Compliance Script")}
$win365usersettings = $configuration | where-object {($_.ID -eq $id) -and ($_.Type -eq "Win365 User Settings")}
$win365provisioning = $configuration | where-object {($_.ID -eq $id) -and ($_.Type -eq "Win365 Provisioning Policy")}
$policysets = $configuration | where-object {($_.ID -eq $id) -and ($_.Type -eq "Policy Set")}
$enrollmentconfigs = $configuration | where-object {($_.ID -eq $id) -and ($_.Type -eq "Enrollment Configuration")}
$devicecategories = $configuration | where-object {($_.ID -eq $id) -and ($_.Type -eq "Device Categories")}
$devicefilters = $configuration | where-object {($_.ID -eq $id) -and ($_.Type -eq "Device Filter")}
$brandingprofiles = $configuration | where-object {($_.ID -eq $id) -and ($_.Type -eq "Branding Profile")}
$adminapprovals = $configuration | where-object {($_.ID -eq $id) -and ($_.Type -eq "Admin Approval")}
$intuneterms = $configuration | where-object {($_.ID -eq $id) -and ($_.Type -eq "Intune Terms")}
$intunerole = $configuration | where-object {($_.ID -eq $id) -and ($_.Type -eq "Intune Role")}
}
else {
    
$policy = Get-DeviceConfigurationPolicy -id $id
$catalog = Get-DeviceConfigurationPolicysc -id $id
$compliance = Get-DeviceCompliancePolicy -id $id
$security = Get-DeviceSecurityPolicy -id $id
$autopilot = Get-AutoPilotProfile -id $id
$esp = Get-AutoPilotESP -id $id
$android = Get-ManagedAppProtectionAndroid -id $id
$ios = Get-ManagedAppProtectionios -id $id
$gp = Get-DeviceConfigurationPolicyGP -id $id
$ca = Get-ConditionalAccessPolicy -id $id
$proac = Get-DeviceProactiveRemediations -id $id
$aad = Get-GraphAADGroups -id $id
$wingetapp = Get-IntuneApplication -id $id
$scripts = Get-DeviceManagementScripts -id $id
$compliancescripts = Get-DeviceCompliancePolicyScripts -id $id
$win365usersettings = Get-Win365UserSettings -id $id
$win365provisioning = Get-Win365ProvisioningPolicies -id $id
$policysets = Get-IntunePolicySets -id $id
$enrollmentconfigs = Get-EnrollmentConfigurations -id $id
$devicecategories = Get-DeviceCategories -id $id
$devicefilters = Get-DeviceFilters -id $id
$brandingprofiles = Get-BrandingProfiles -id $id
$adminapprovals = Get-AdminApprovals -id $id
#$orgmessages = Get-OrgMessages -id $id
$intuneterms = Get-IntuneTerms -id $id
$intunerole = Get-IntuneRoles -id $id
}




# Copy it
if ($null -ne $policy) {
    # Standard Device Configuratio Policy
write-host "It's a policy"
$id = $policy.id
$Resource = "deviceManagement/deviceConfigurations"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$profiles+= ,(@($copypolicy[0],$copypolicy[1], $id))

}
if ($null -ne $gp) {
    # Standard Device Configuratio Policy
write-host "It's an Admin Template"
$id = $gp.id
$Resource = "deviceManagement/groupPolicyConfigurations"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$profiles+= ,(@($copypolicy[0],$copypolicy[1], $id))
}
if ($null -ne $catalog) {
    # Settings Catalog Policy
write-host "It's a Settings Catalog"
$id = $catalog.id
$Resource = "deviceManagement/configurationPolicies"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$profiles+= ,(@($copypolicy[0],$copypolicy[1], $id))

}
if ($null -ne $compliance) {
    # Compliance Policy
write-host "It's a Compliance Policy"
$id = $compliance.id
$Resource = "deviceManagement/deviceCompliancePolicies"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$profiles+= ,(@($copypolicy[0],$copypolicy[1], $id))

}
if ($null -ne $proac) {
    # Proactive Remediations
write-host "It's a Proactive Remediation"
$id = $proac.id
$Resource = "deviceManagement/devicehealthscripts"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$profiles+= ,(@($copypolicy[0],$copypolicy[1], $id))

}

if ($null -ne $scripts) {
    # Device Scripts
    write-host "It's a PowerShell Script"
$id = $scripts.id
$Resource = "deviceManagement/devicemanagementscripts"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$profiles+= ,(@($copypolicy[0],$copypolicy[1],$copypolicy[2], $id))
}


if ($null -ne $compliancescripts) {
    # Compliance Scripts
    write-host "It's a Compliance Script"
$id = $compliancescripts.id
$Resource = "deviceManagement/deviceComplianceScripts"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$profiles+= ,(@($copypolicy[0],$copypolicy[1],$copypolicy[2], $id))
}

if ($null -ne $security) {
    # Security Policy
write-host "It's a Security Policy"
$id = $security.id
$Resource = "deviceManagement/intents"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$profiles+= ,(@($copypolicy[0],$copypolicy[1], $id))

}
if ($null -ne $autopilot) {
    # Autopilot Profile
write-host "It's an Autopilot Profile"
$id = $autopilot.id
$Resource = "deviceManagement/windowsAutopilotDeploymentProfiles"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$profiles+= ,(@($copypolicy[0],$copypolicy[1], $id))

}
if ($null -ne $esp) {
    # Autopilot ESP
write-host "It's an AutoPilot ESP"
$id = $esp.id
$Resource = "deviceManagement/deviceEnrollmentConfigurations"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$profiles+= ,(@($copypolicy[0],$copypolicy[1], $id))

}
if ($null -ne $android) {
    # Android App Protection
write-host "It's an Android App Protection Policy"
$id = $android.id
$Resource = "deviceAppManagement/managedAppPoliciesandroid"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$profiles+= ,(@($copypolicy[0],$copypolicy[1], $id))

}
if ($null -ne $ios) {
    # iOS App Protection
write-host "It's an iOS App Protection Policy"
$id = $ios.id
$Resource = "deviceAppManagement/managedAppPoliciesios"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$profiles+= ,(@($copypolicy[0],$copypolicy[1], $id))

}
if ($null -ne $aad) {
    # AAD Groups
write-host "It's an AAD Group"
$id = $aad.id
$Resource = "groups"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$profiles+= ,(@($copypolicy[0],$copypolicy[1], $id))

}
if ($null -ne $ca) {
    # Conditional Access
write-host "It's a Conditional Access Policy"
$id = $ca.id
$Resource = "ConditionalAccess"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$profiles+= ,(@($copypolicy[0],$copypolicy[1], $id))

}
if ($null -ne $wingetapp) {
    # Winget App
write-host "It's a Windows Application"
$id = $wingetapp.id
$Resource = "deviceAppManagement/mobileApps"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$profiles+= ,(@($copypolicy[0],$copypolicy[1], $id))
}
if ($null -ne $win365usersettings) {
    # W365 User Settings
write-host "It's a W365 User Setting"
$id = $win365usersettings.id
$Resource = "deviceManagement/virtualEndpoint/userSettings"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$profiles+= ,(@($copypolicy[0],$copypolicy[1], $id))
}
if ($null -ne $win365provisioning) {
    # W365 Provisioning Policy
write-host "It's a W365 Provisioning Policy"
$id = $win365provisioning.id
$Resource = "deviceManagement/virtualEndpoint/provisioningPolicies"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$profiles+= ,(@($copypolicy[0],$copypolicy[1], $id))
}
if ($null -ne $policysets) {
    # Policy Set
write-host "It's a Policy Set"
$id = $policysets.id
$Resource = "deviceAppManagement/policySets"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$profiles+= ,(@($copypolicy[0],$copypolicy[1], $id))
}
if ($null -ne $enrollmentconfigs) {
    # Enrollment Config
write-host "It's an enrollment configuration"
$id = $enrollmentconfigs.id
$Resource = "deviceManagement/deviceEnrollmentConfigurations"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$profiles+= ,(@($copypolicy[0],$copypolicy[1], $id))
}
if ($null -ne $devicecategories) {
    # Device Categories
write-host "It's a device category"
$id = $devicecategories.id
$Resource = "deviceManagement/deviceCategories"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$profiles+= ,(@($copypolicy[0],$copypolicy[1], $id))
}
if ($null -ne $devicefilters) {
    # Device Filter
write-host "It's a device filter"
$id = $devicefilters.id
$Resource = "deviceManagement/assignmentFilters"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$profiles+= ,(@($copypolicy[0],$copypolicy[1], $id))
}
if ($null -ne $brandingprofiles) {
    # Branding Profile
write-host "It's a branding profile"
$id = $brandingprofiles.id
$Resource = "deviceManagement/intuneBrandingProfiles"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$profiles+= ,(@($copypolicy[0],$copypolicy[1], $id))
}
if ($null -ne $adminapprovals) {
    # Multi-admin approval
write-host "It's a multi-admin approval"
$id = $adminapprovals.id
$Resource = "deviceManagement/operationApprovalPolicies"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$profiles+= ,(@($copypolicy[0],$copypolicy[1], $id))
}
#if ($null -ne $orgmessages) {
    # Organizational Message
#write-host "It's an organizational message"
#$id = $orgmessages.id
#$Resource = "deviceManagement/organizationalMessageDetails"
#$copypolicy = getpolicyjson -resource $Resource -policyid $id
#$profiles+= ,(@($copypolicy[0],$copypolicy[1], $id))
#}
if ($null -ne $intuneterms) {
    # Intune Terms
write-host "It's a T&C"
$id = $intuneterms.id
$Resource = "deviceManagement/termsAndConditions"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$profiles+= ,(@($copypolicy[0],$copypolicy[1], $id))
}
if ($null -ne $intunerole) {
    # Intune Role
write-host "It's a role"
$id = $intunerole.id
$Resource = "deviceManagement/roleDefinitions"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$profiles+= ,(@($copypolicy[0],$copypolicy[1], $id))
}
}


        ##Clear Tenant Connections
        Disconnect-MgGraph
        
        ##Get new Tenant details
        write-host "Connecting to destination tenant"
        if ($automated -eq "yes") {
 
            $body = @{
                grant_type="client_credentials";
                client_id=$clientId;
                client_secret=$clientSecret;
                scope="https://graph.microsoft.com/.default";
            }
             
            $response = Invoke-RestMethod -Method Post -Uri https://login.microsoftonline.com/$desttenant/oauth2/v2.0/token -Body $body
            $accessToken = $response.access_token
             
            $accessToken
        
            Select-MgProfile -Name Beta
        Connect-MgGraph  -AccessToken $accessToken 
        write-host "Graph Connection Established"
        }
        else {
        ##Connect to Graph
        Select-MgProfile -Name Beta
        Connect-MgGraph -Scopes DeviceManagementServiceConfig.ReadWrite.All, RoleAssignmentSchedule.ReadWrite.Directory, Domain.Read.All, Domain.ReadWrite.All, Directory.Read.All, Policy.ReadWrite.ConditionalAccess, DeviceManagementApps.ReadWrite.All, DeviceManagementConfiguration.ReadWrite.All, DeviceManagementManagedDevices.ReadWrite.All, openid, profile, email, offline_access, DeviceManagementRBAC.Read.All, DeviceManagementRBAC.ReadWrite.All
        }        


    ##Loop through array and create Profiles
        foreach ($toupload in $profiles) {
            $policyuri =  $toupload[1]
            $policyjson =  $toupload[0]
            $id = $toupload[2]
            $policy = $policyjson
            ##If policy is conditional access, we need special config
            if ($policyuri -eq "conditionalaccess") {
                write-host "Creating Conditional Access Policy"
                $uri = "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies"
                $NewDisplayName = "Copy of " + $Policy.DisplayName
                $Parameters = @{
                    displayName     = $NewDisplayName
                    state           = $policy.State
                    conditions      = $policy.Conditions
                    grantControls   = $policy.GrantControls
                    sessionControls = $policy.SessionControls
                }
                $body = $Parameters | ConvertTo-Json -depth 50
               $null = Invoke-MgGraphRequest -Method POST -uri $uri -Body $body -ContentType "application/json"
            }
            else {

               # Add the policy
            $body = ([System.Text.Encoding]::UTF8.GetBytes($policyjson.tostring()))
            #$copypolicy = Invoke-RestMethod -Uri $policyuri -Headers $authToken -Method Post -Body $body  -ContentType "application/json; charset=utf-8"  
            $copypolicy = Invoke-MgGraphRequest -Uri $policyuri -Method Post -Body $body  -ContentType "application/json; charset=utf-8"



            ##If policy is an admin template, we need to loop through and add the settings
            if ($policyuri -eq "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations") {
                ##Now grab the JSON
                $GroupPolicyConfigurationsDefinitionValues = Get-GroupPolicyConfigurationsDefinitionValues -GroupPolicyConfigurationID $id
                $OutDefjson = @()
	                foreach ($GroupPolicyConfigurationsDefinitionValue in $GroupPolicyConfigurationsDefinitionValues)
	                    {
		                    $GroupPolicyConfigurationsDefinitionValue
		                    $DefinitionValuedefinition = Get-GroupPolicyConfigurationsDefinitionValuesdefinition -GroupPolicyConfigurationID $id -GroupPolicyConfigurationsDefinitionValueID $GroupPolicyConfigurationsDefinitionValue.id
		                    $DefinitionValuedefinitionID = $DefinitionValuedefinition.id
		                    $DefinitionValuedefinitionDisplayName = $DefinitionValuedefinition.displayName
                            $DefinitionValuedefinitionDisplayName = $DefinitionValuedefinitionDisplayName
		                    $GroupPolicyDefinitionsPresentations = Get-GroupPolicyDefinitionsPresentations -groupPolicyDefinitionsID $id -GroupPolicyConfigurationsDefinitionValueID $GroupPolicyConfigurationsDefinitionValue.id
		                    $DefinitionValuePresentationValues = Get-GroupPolicyConfigurationsDefinitionValuesPresentationValues -GroupPolicyConfigurationID $id -GroupPolicyConfigurationsDefinitionValueID $GroupPolicyConfigurationsDefinitionValue.id
		                    $OutDef = New-Object -TypeName PSCustomObject
                            $OutDef | Add-Member -MemberType NoteProperty -Name "definition@odata.bind" -Value "https://graph.microsoft.com/beta/deviceManagement/groupPolicyDefinitions('$definitionValuedefinitionID')"
                            $OutDef | Add-Member -MemberType NoteProperty -Name "enabled" -value $($GroupPolicyConfigurationsDefinitionValue.enabled.tostring().tolower())
                                if ($DefinitionValuePresentationValues) {
                                    $i = 0
                                    $PresValues = @()
                                    foreach ($Pres in $DefinitionValuePresentationValues) {
                                        $P = $pres | Select-Object -Property * -ExcludeProperty id, createdDateTime, lastModifiedDateTime, version
                                        $GPDPID = $groupPolicyDefinitionsPresentations[$i].id
                                        $P | Add-Member -MemberType NoteProperty -Name "presentation@odata.bind" -Value "https://graph.microsoft.com/beta/deviceManagement/groupPolicyDefinitions('$definitionValuedefinitionID')/presentations('$GPDPID')"
                                        $PresValues += $P
                                        $i++
                                    }
                                $OutDef | Add-Member -MemberType NoteProperty -Name "presentationValues" -Value $PresValues
                                }
		                    $OutDefjson += ($OutDef | ConvertTo-Json -Depth 10).replace("\u0027","'")
                            foreach ($json in $OutDefjson) {
                                $graphApiVersion = "beta"
                                $policyid = $copypolicy.id
                                $DCP_resource = "deviceManagement/groupPolicyConfigurations/$($policyid)/definitionValues"
                                $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
			                    #Invoke-RestMethod -ErrorAction SilentlyContinue -Uri $uri -Headers $authToken -Method Post -Body $json -ContentType "application/json"
                                try {
                                Invoke-MgGraphRequest -Uri $uri -Method Post -Body $json -ContentType "application/json"
                                }
                                catch {}
                            }
                        }
            }

        }

            }

        ##Clear Tenant Connections
Disconnect-MgGraph

Stop-Transcript