<#
  .SYNOPSIS
  add virtual network objects to multiple private zones at scale

  .DESCRIPTION
  This script will find all the private zones in a specific resource group and then add private links for the networks
  declared in the network array. If the target subscription names have spaces will have spaces removed to align with link 
  naming conditions. Link will be 
  [private zone name]+[subscription name]+[environment code]+[region abbreviation] 
  [private.contso.com][microsoftvs][p][uw1]
  private2.contoso.com-microsoftvs-p-uw1

  This script also assumes that the account authenticate does have access to all subscriptionId's detailed in the networking
  objects. Please ensure the shell context is set to the subscription where the private DNS Zone resource group exists before running.

  .PARAMETER privateZoneResourceGroup
  The resource group where the private zones exist

#>
## ----------------------------------------------------------------------------------
## THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, 
## EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES 
## OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
## ----------------------------------------------------------------------------------
Param (
    [Parameter(Mandatory=$true)]  
    [string]$privateZoneResourceGroup
)

 $WarningPreference = "SilentlyContinue"
 Class Network {
     [string]$networkName
     [string]$resourceGroupName
     [string]$subscriptionId
     [string]$regionAbbreviation
     [string]$environmentCode
     
     [object] getNetworkObject(){
        $context = Get-AzContext 
        Select-AzSubscription -SubscriptionId $this.subscriptionId

        $networkObj = Get-AzResource -Name $this.networkName `
                                     -ResourceGroupName $this.resourceGroupName 

        Select-AzSubscription -SubscriptionId $context.Subscription.Id
        return $networkObj       
     }

     [string] getSubscriptionName() {
         return ((Get-AzSubscription -SubscriptionId $this.subscriptionId).Name).Replace(' ','')
     }
 }

 # EXAMPLE
 # $networkArr = @(
 #    [Network]@{
 #        subscriptionId='04b605b4-37f1-4b89-9ca8-bvwc9962c71';
 #        networkName='openvpn-vnet';
 #        resourceGroupName='openvpn';
 #        regionAbbreviation='UW1';
 #        environmentCode='d';
 #    }
 #    [Network]@{
 #        subscriptionId='332236a1-0cc9-r6f9-be63-4gj2b10598eb';
 #        networkName='AVD_Support-vnet';
 #        resourceGroupName='AVD_Support';
 #        regionAbbreviation='UW1';
 #        environmentCode='p';
 #     }
 # )

$networkArr = @(
   [Network]@{
       subscriptionId='';
       networkName='';
       resourceGroupName='';
       regionAbbreviation='';
       environmentCode='';
   }
)

if(!$networkArr){
    Write-Error "Please instantiate a Network Array"
    exit
}

Function Get-PrivateZones($privateZoneRG){
    try{
        $zones = Get-AzPrivateDnsZone -ResourceGroupName $privateZoneRG
    }
    catch{
        Write-Error "Private Zones not found in passed resource group"
        exit
    }
    return $zones
}

Function New-NetworkLink($networkObj,$subscriptionName,$environmentCode,$regionAbbreviation,$zoneName,$zoneRG){
    New-AzPrivateDnsVirtualNetworkLink -Name "$($zoneName)-$($subscriptionName)-$($environmentCode)-$($regionAbbreviation)" `
                                       -ZoneName $zoneName `
                                       -ResourceGroupName $zoneRG `
                                       -VirtualNetworkId $networkObj.id `
}

$privateZones = Get-PrivateZones -privateZoneRG $privateZoneResourceGroup
Write-Output "Found $(($privateZones).count) private Zones in the $($privateZoneResourceGroup) resource group"
Write-Output ($privateZones | Select-Object name)

foreach ($network in $networkArr) {
    foreach ($zone in $privateZones){
        $links += ((New-NetworkLink -networkObj $network.getNetworkObject() `
                                    -subscriptionName $network.getSubscriptionName() `
                                    -regionAbbreviation $network.regionAbbreviation `
                                    -environmentCode $network.environmentCode `
                                    -zoneName $zone.name `
                                    -zoneRG $zone.resourceGroupName).name)+"`n"
    }
}

Write-Output "Links Created: `n $($links)"


