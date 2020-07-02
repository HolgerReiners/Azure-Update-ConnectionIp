################################################################################################
# Update-ConnectionIp.ps1
# 
# AUTHOR: Holger Reiners, Microsoft Deutschland GmbH
# VERSION: 0.1
# DATE: 01.07.2020
#
# purpose:
#   Update a Azure local network gateway connection IP address from a dynamic DNS entry.
#   This enables the use of a VPN GW isbehind a dynamic IP with DynDNSname and a Azure VPN Gateway.
# 
# prerequisites:
#   - Authenticated management session to the Azure cloud environment OR
#     Azure Automation with "Run As Account"
#   - correct subscription is selected and active
#   - Powershell Az commands are installed - https://docs.microsoft.com/en-us/powershell/azure/
#   - Azure Automation - modules available: Az.Accounts, Az.Network
#
# input:
#   - DynDNSname - Dynamic DNS Entry to check against the local network gateway connection IP
#   - connectionName - Connection Name of Azure Automation (usualy AzureRunAsConnection) (optional)
#   - resourceGroup - the resource group where the local gateway resides
#   - localGatewayName - name of the local gateway resource
#   - NoAzureAutomation - SWITCH to signal the script that is running outside of Azure Automation (optional)
#
# output:
#   - updated connection object in the Azure cloud environment
#
# additional information:
#
# THIS CODE-SAMPLE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED 
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR 
# FITNESS FOR A PARTICULAR PURPOSE.
#
# This sample is not supported under any Microsoft standard support program or service. 
# The script is provided AS IS without warranty of any kind. Microsoft further disclaims all
# implied warranties including, without limitation, any implied warranties of merchantability
# or of fitness for a particular purpose. The entire risk arising out of the use or performance
# of the sample and documentation remains with you. In no event shall Microsoft, its authors,
# or anyone else involved in the creation, production, or delivery of the script be liable for 
# any damages whatsoever (including, without limitation, damages for loss of business profits, 
# business interruption, loss of business information, or other pecuniary loss) arising out of 
# the use of or inability to use the sample or documentation, even if Microsoft has been advised 
# of the possibility of such damages.
################################################################################################

<#
.SYNOPSIS  
   update a Azure connection object IP address, if the other VPN GW is on a dynamic IP with DynDNSname.
.DESCRIPTION
    Update a Azure local network gateway connection IP address from a dynamic DNS entry.
    This enables the use of a VPN GW isbehind a dynamic IP with DynDNSname and a Azure VPN Gateway.
    
.NOTES  
    File Name  : Update-ConnectionIp
    Author     : Holger Reiners
.LINK  
    https://github.com/HolgerReiners
.EXAMPLE
.\Update-ConnectionIp.ps1 -NoAzAutomation -DynDNS myhost.dyndns.com -resourceGroup AzResGroupName -localGatewayName vpngw01-dyndns-lng"

.PARAMETER DynDNSname
    specify the dynamic DNS name to use for the VPN gateway behind the dynamic IP
.PARAMETER connectionName
    specify the Azure Automation connection name to use (usualy AzureRunAsConnection)
.PARAMETER localGatewayName
    specify the local gateway name to use in the operation
.PARAMETER resourceGroup
    Azure resource group name where the object exist
.PARAMETER NoAzAutomation
    SWITCH to signal the script that is running outside of Azure Automation with the existing Azure connection in the session
#>

######### Parameters #########
param (
    [Parameter(Mandatory = $true)]
        [array] $DynDNSname,

    [Parameter(Mandatory = $true)]
        [string] $resourceGroup, 
    
    [Parameter(Mandatory = $true)]
        [string] $localGatewayName,
    
    [Parameter(Mandatory = $false)]
        [string] $connectionName = "AzureRunAsConnection", 
    
    [Parameter(Mandatory = $false)]
        [switch] $NoAzAutomation = $false
)

######### Main #########
Write-Output "--- Update-ConnectionIp ---"

# Login with the Azure Automation account
if (!($NoAzAutomation.IsPresent)) {
    try {
        # Get the connection "AzureRunAsConnection "
        $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

        Write-Output "login with Azure Automation account"
        $AzAutomationConnection = Connect-AzAccount `
            -ServicePrincipal `
            -TenantId $servicePrincipalConnection.TenantId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
    }
    catch {
        if (!$servicePrincipalConnection) {
            $ErrorMessage = "Connection $connectionName not found."
            throw $ErrorMessage
        }
        else {
            Write-Error -Message $_.Exception
            throw $_.Exception
        }
    }
} else {
    Write-Output "use existing Azure Connection"
}

# start processing
Write-Output "Working parameters"
Write-Output "   DynDNSname:       $DynDNSname"
Write-Output "   connectionName:   $connectionName"
Write-Output "   resourceGroup:    $resourceGroup"
Write-Output "   localGatewayName: $localGatewayName"

Write-Output "get IP address from DNS name"
#Get IP based on the Domain Name 
[string]$IP = ([System.Net.DNS]::GetHostAddresses($DynDNSname)).IPAddressToString 
Write-Output "   $DynDNSname = $IP"

Write-Output "get IP address from connection"
$localGW = Get-AzLocalNetworkGateway -Name $localGatewayName -ResourceGroupName $resourceGroup

$currentIP = $localGW.GatewayIpAddress
Write-Output "   CurrentIP = $currentIP"
if($IP -ne $currentIP)
{
	"IP update started ..."
	$localGW.GatewayIpAddress = $IP
	Set-AzLocalNetworkGateway -LocalNetworkGateway $localGW
	"IP address changed"
}
else 
{
	"IP is already up-to-date"	
}
Write-Output "--- Update-ConnectionIp END ---"