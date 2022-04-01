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
  [int]$PolicyPriority,
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
    $ruleCollection = @()
    $WarningPreference = 'SilentlyContinue'

    foreach ($rule in $RulesfromCSV)
    {
        $RuleParameter = @{
            Name                    = $rule.Name;
            Protocol                = $rule.protocols
            sourceAddress           = $rule.SourceAddresses
            DestinationAddress      = $rule.DestinationAddresses
            DestinationPort         = $rule.DestinationPorts
            DestinationIPGroup      = $null
        }
        if($rule.SourceIPGroups){$RuleParameter.Add("SourceIPGroup",$rule.SourceIPGroups)}
        if($rule.DestinationFQDNs){$RuleParameter.Add("DestinationFQDN",$rule.DestinationFQDNs)}
        if($rule.DestinationIPGroups){$RuleParameter.Add("DestinationIPGroup",$rule.DestinationIPGroups)}

        $ruleObject = New-AzFirewallPolicyNetworkRule @RuleParameter -

        $NetworkRuleCollection = @{
            Name        = $rule.RuleCollectionName
            Priority    = $rule.RulePriority
            ActionType  = $rule.ActionType
            Rule        = $ruleCollection+= $ruleObject
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
                                                                                    -Priority $PolicyPriority `
                                                                                    -FirewallPolicyObject $AzureFirewallPolicyObject


$RulesfromCSV = Get-CSVRules -CSVPath $CSVPath
$networkRuleCollection = Import-FirewallRules -RulesfromCSV $RulesfromCSV


$NetworkRuleCollectionObject = New-AzFirewallPolicyFilterRuleCollection @networkRuleCollection

Set-AzFirewallPolicyRuleCollectionGroup -Name $AzureFirewallPolicyCollectionGroupObject.Name `
                                        -Priority $PolicyPriority `
                                        -RuleCollection $NetworkRuleCollectionObject `
                                        -FirewallPolicyObject $AzureFirewallPolicyObject