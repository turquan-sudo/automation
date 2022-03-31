<#
  .SYNOPSIS
  Import script used in conjunction with the associated export script for Azure firewall rules
  .DESCRIPTION
  
  .PARAMETER AzureFirewallPolicyName
  The target Azure firewall policy name

#>
## ----------------------------------------------------------------------------------
## THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, 
## EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES 
## OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
## ----------------------------------------------------------------------------------
Param (
  [string]$AzureFirewallPolicyName,
  [string]$AzureFirewallPolicyResourceGroupName, 
  [string]$PolicyCollectionGroupName,
  [string]$CSVPath
)

Function Get-CSVRules ($CSVPath) {
    $RulesfromCSV = @()

    try{
        $CSVObject = Import-CSV $CSVPath
    }
    Catch{
        write:output $_Exception.Message
        exit
    }

    foreach ($object in $CSVObject)
    {
        $properties = [ordered]@{
            RuleCollectionName = $object.RuleCollectionName;
            RulePriority = $object.RulePriority;
            ActionType = $object.ActionType;
            Name = $object.Name;
            protocols = $object.protocols -split ", ";
            SourceAddresses = $object.SourceAddresses -split ", ";
            DestinationAddresses = $object.DestinationAddresses -split ", ";
            SourceIPGroups = $object.SourceIPGroups -split ", ";
            DestinationIPGroups = $object.DestinationIPGroups -split ", ";
            DestinationPorts = $object.DestinationPorts -split ", ";
            DestinationFQDNs = $object.DestinationFQDNs -split ", ";
        }
        $tmpObject = New-Object psobject -Property $properties
        $RulesfromCSV += $tmpObject
    }

    return $RulesfromCSV
}

Function Import-FirewallRules ($RulesfromCSV) {

    foreach ($entry in $RulesfromCSV)
    {
        $RuleParameter = @{
            Name = $entry.Name;
            Protocol = $entry.protocols
            sourceAddress = $entry.SourceAddresses
            DestinationAddress = $entry.DestinationAddresses
            DestinationPort = $entry.DestinationPorts
        }

        $rule = New-AzFirewallPolicyNetworkRule @RuleParameter

        $NetworkRuleCollection = @{
            Name = $entry.RuleCollectionName
            Priority = $entry.RulePriority
            ActionType = $entry.ActionType
            Rule       = $rules += $rule
        }
    }

    return $NetworkRuleCollection
}

############
# Main
############
$AzureFirewallPolicyObject = Get-AzFirewallPolicy -Name $AzureFirewallPolicyName `
                                                  -ResourceGroupName $AzureFirewallPolicyResourceGroupName

$AzureFirewallPolicyCollectionGroupObject = New-AzFirewallPolicyRuleCollectionGroup -Name $PolicyCollectionGroupName `
                                                                                    -Priority 200 `
                                                                                    -FirewallPolicyObject $AzureFirewallPolicyObject


$RulesfromCSV = Get-CSVRules -CSVPath $CSVPath
$networkRuleCollection = Import-FirewallRules -RulesfromCSV $RulesfromCSV


$NetworkRuleCollectionObject = New-AzFirewallPolicyFilterRuleCollection $networkRuleCollection

Set-AzFirewallPolicyRuleCollectionGroup -Name $AzureFirewallPolicyCollectionGroupObject.Name `
                                        -Priority 200 `
                                        -RuleCollection $NetworkRuleCollectionObject `
                                        -FirewallPolicyObject $AzureFirewallPolicyCollectionGroupObject