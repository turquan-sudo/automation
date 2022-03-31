
  <#
      .SYNOPSIS
      This script can be used to automate pim settings 
      .DESCRIPTION
      This script can be used to assing specific settings and configuration for PIM and Azure RBAC.  
      .PARAMETER ResourceGroupName
      The name of the resource group that contains VMs to add NSGs and JIT to
      .PARAMETER ConnectionName
      Azure automation Service Principle name
  #>

  Param (
    [string]$SubscriptionID = "526a84d0-b605-4e5a-bdf4-a9069917b1df",
    [string]$RoleDefinitionID = "b12aa53e-6015-4669-85d0-8515ebb3ae7f", 
    [string]$activationMFA = "true",
    [string[]]$Principals
  )
  #"b24988ac-6180-42a0-ab88-20f7382dd24c" #Contributor Example

      Function Connect-AAD(){
        $context = Get-AzContext
        $context = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile.DefaultContext
        $graphToken = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.Id.ToString(), $null, [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, $null, "https://graph.microsoft.com").AccessToken
        $aadToken = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.Id.ToString(), $null, [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, $null, "https://graph.windows.net").AccessToken
        Write-Output "Connected to account $($context.Account.Id)"
        Connect-AzureAD -AadAccessToken $aadToken -AccountId $context.Account.Id -TenantId $context.tenant.id -MsAccessToken $graphToken -Verbose

      }

      Function Find-Resources($SubscriptionID){
            try{
                Add-AzureADMSPrivilegedResource -ProviderId AzureResources -ExternalId "/subscriptions/$($.subscriptionID)"
                $SubscriptionPrivilegedResource = Get-AzureADMSPrivilegedResource -ProviderId AzureResources `
                                                                | Where-Object{ ($_.type -eq 'subscription') -and ($_.ExternalId -eq "/subscriptions/$($subscriptionId)")}

            }
            catch{
                Write-Error "Privileged Roles not found, possible SP permissions error"
                Exit 1
            }
            return $SubscriptionPrivilegedResource
      }

      Function Get-PrivilgedRoleSetting($SubscriptionPrivilegedResources){
          try{
            $privilegedRoleSetting = Get-AzureADMSPrivilegedRoleSetting `
                                               -ProviderId AzureResources `
                                               -Filter "ResourceId eq '$($SubscriptionPrivilegedResource.Id)' and RoleDefinitionId eq '$roleDefinitionID'"
          }
          catch{
              return "Role Setting not found"
          }
          return $privilegedRoleSetting
      }

      Function Add-ActivationPriviligedSettingMap(){
        $UserMemberPrivilegedRuleSetting = New-Object Microsoft.Open.MSGraph.Model.AzureADMSPrivilegedRuleSetting
        $UserMemberPrivilegedRuleSetting.RuleIdentifier = "MfaRule"
        $UserMemberPrivilegedRuleSetting.Setting = "{""mfaRequired"":$($ActivationMFA)}"
        return $UserMemberPrivilegedRuleSetting
      }

      Function Set-PriviligedMap($PrivilegedRoleSettingID, $UserMemberRuleSetting, $AdminMemberRuleSet, $AdminElibigleRuleSet){
        ##UserMemberSettings == Activation settings
        ##AdminEligibleSettings == Assignment settings
        ##AdminMemberSettings == Active Assignments
        
        Set-AzureADMSPrivilegedRoleSetting -ProviderId AzureResources `
                                           -Id $PrivilegedRoleSettingID `
                                           -UserMemberSettings $UserMemberRuleSetting

        #Set-AzureADMSPrivilegedRoleSetting -ProviderId AzureResources `
        #                                   -Id $PrivilegedRoleSettingID `
        #                                   -AdminMemberSettings $AdminMemberRuleSet
#
        #Set-AzureADMSPrivilegedRoleSetting -ProviderId AzureResources `
        #                                   -Id $PrivilegedRoleSettingIDd `
        #                                   -AdminEligibleSettings  $AdminElibigleRuleSet
      }


    
      Connect-AAD
      $SubscriptionPrivilegedResources = Find-Resources -SubscriptionID $SubscriptionID
      $PrivilegedRoleSetting = Get-PrivilgedRoleSetting

      
      $SettingMap = Add-ActivationPriviligedSettingMap
      Set-PriviligedMap -PrivilegedRoleSettingID $PrivilegedRoleSetting.Id `
                        -UserMemberRuleSetting $UserMemberRuleSetting

      If($Principals){
        
      }

