
  <#
      .SYNOPSIS
      This script will consolidate DNS records to a single Azure DNS Zone Record
      .DESCRIPTION
      The script is designed to run inside of an already authenticated cloudshell instance - shell.azure.com
      Network links will need to be populated prior to consolidation
      .PARAMETER TargetZone
      TThe Target Zone name to consolidate
      .PARAMETER TargetZoneSubscription
      The Subscription ID where the target zone is located
      .PARAMETER TargetZoneResourceGroup
      The resource group name where the target zone exists
      .PARAMETER DestinationSubscription
      The Subscription ID of the destination Subscription
      .PARAMETER DestinationResourceGroup
      The Destination Resource Group Name
      .PARAMETER RemoveZone
      This Flag will Remove the Source Zone
  #>

  Param (
    [string]$TargetZone = "",
    [string]$TargetZoneSubscription = "", 
    [string]$TargetZoneResourceGroup = "", 
    [string]$DestinationSubscription = "",
    [string]$DestinationResourceGroup = "",
    [switch]$RemoveZone
  )

Set-AzContext -SubscriptionId $TargetZoneSubscription
$zone = Get-AzPrivateDnsZone -Name $TargetZone -ResourceGroupName $TargetZoneResourceGroup
$records += Get-AzPrivateDnsRecordSet -Zone $zone  | ?{$_.RecordType -eq 'A'}

Write-Output $records

Set-AzContext -SubscriptionId $DestinationSubscription 
If(!(Get-AzPrivateDNSZone -ResourceGroupName $DestinationResourceGroup -OutVariable TargetZoneObject)){
    Write-Output "Creating New Private DNS Zone $($TargetZone) in $($DestinationResourceGroup) : $($DestinationSubscription)"
    $targetZoneObject = New-AzPrivateDnsZone -Name $TargetZone `
                                             -ResourceGroupName $DestinationResourceGroup 

    Write-Output "$($TargetZoneObject.Name) Created"
}else {
    Write-Output "$($TargetZoneObject.Name) Found"
}

Write-Output "Populating destination DNS Zone..."
foreach ($record in $records){
    New-AzPrivateDnsRecordSet -name $record.Name `
                              -ZoneName $targetZoneObject.Name `
                              -RecordType $record.RecordType `
                              -Ttl $record.Ttl `
                              -ResourceGroupName $DestinationResourceGroup `
                              -PrivateDnsRecord $record.Records
} 


If($RemoveZone){
    Set-Content -SubscriptionId $TargetZoneSubscription
    foreach ($record in $records){
        Remove-AzPrivateDnsRecordSet -name $record.Name `
                                  -ZoneName $TargetZone `
                                  -ResourceGroupName $TargetZoneResourceGroup `
                                  -RecordType $record.RecordType 
        Write-Output "Removed Record $($record.name)  $($record.RecordType)  with TTL $($record.Ttl) from $($TargetZone) in $($TargetZoneResourceGroup)"
    }

    If(Get-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $TargetZoneResourceGroup -ZoneName $TargetZone -OutVariable VnetLinkObj){
        Write-Out "VNet Links Found"
        foreach ($link in $VnetLinkObj){
            Write-Output "VNet Link $($link.Name) being removed..."
            Remove-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $TargetZoneResourceGroup -ZoneName $TargetZone -Name $link.name
        }
    }

    Remove-AzPrivateDnsZone -ResourceGroupName $TargetZoneResourceGroup -Name $TargetZone 
}

