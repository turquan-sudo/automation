<#
  .SYNOPSIS
  Export script used in conjunction with the associated Import script for Azure firewall rules

  .DESCRIPTION
  This script can be used to export Azure Firewall Policy Collections.  The exported CSV can be used by Import-AzfwPolicies.ps1 to add new Rules
  to an existing collection or create a new collection

  .PARAMETER AzureFirewallPolicyName
  The target Azure firewall policy name

  .PARAMETER AzureFirewallPolicyResourceGroupName
  The resource group in which the policy currently exists

  .PARAMETER PolicyCollectionGroupName
  The Policy collection name

  .PARAMETER CSVPath
  The target folder for azfwPolicy.csv to be exported to

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

Function New-PolicyObject($CollectionGroup) {

    $returnObj = @()

    foreach ($rulecol in $CollectionGroup.Properties.RuleCollection) {

        foreach ($rule in $rulecol.rules)
        {
                $properties = [ordered]@{
                    RuleCollectionName = $rulecol.Name;
                    RulePriority = $rulecol.Priority;
                    ActionType = $rulecol.Action.Type;
                    RUleConnectionType = $rulecol.RuleCollectionType;
                    Name = $rule.Name;
                    protocols = $rule.protocols -join ", ";
                    SourceAddresses = $rule.SourceAddresses -join ", ";
                    DestinationAddresses = $rule.DestinationAddresses -join ", ";
                    SourceIPGroups = $rule.SourceIPGroups -join ", ";
                    DestinationIPGroups = $rule.DestinationIPGroups -join ", ";
                    DestinationPorts = $rule.DestinationPorts -join ", ";
                    DestinationFQDNs = $rule.DestinationFQDNs -join ", ";
                }
            $tmpObject = New-Object psobject -Property $properties
            $returnObj += $tmpObject
        }
    }
    Return $returnObj
}

Function Create-CSV($Policies, $CSVPath){
    $Policies | Export-Csv -Path $CSVPath -NoTypeInformation
}

$AzureFirewallPolicyObject = Get-AzFirewallPolicy -Name $AzureFirewallPolicyName `
                                                  -ResourceGroupName $AzureFirewallPolicyResourceGroupName

$AzureFirewallPolicyCollectionGroupObject = Get-AzFirewallPolicyRuleCollectionGroup -Name $PolicyCollectionGroupName `
                                                                                    -AzureFirewallPolicy $AzureFirewallPolicyObject

$PoliciesObject = New-PolicyObject -CollectionGroup $AzureFirewallPolicyCollectionGroupObject
Create-CSV -Policies $PoliciesObject -CSVPath "$($CSVPath)\azfwPolicy.csv"