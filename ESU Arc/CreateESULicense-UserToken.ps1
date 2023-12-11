<# 
//-----------------------------------------------------------------------

THE SUBJECT SCRIPT IS PROVIDED “AS IS” WITHOUT ANY WARRANTY OF ANY KIND AND SHOULD ONLY BE USED FOR TESTING OR DEMO PURPOSES.
YOU ARE FREE TO REUSE AND/OR MODIFY THE CODE TO FIT YOUR NEEDS

//-----------------------------------------------------------------------

.SYNOPSIS
Creates (or updates) an ESU license to be used with Azure ARC.

.DESCRIPTION
This script will create (or modify) ESU licenses for use with Azure Arc


.LINK
To get more information on Azure ARC ESU license REST API please visit:
https://learn.microsoft.com/en-us/azure/azure-arc/servers/api-extended-security-updates

.EXAMPLE-1
./CreateESULicense -subscriptionId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" `
-licenseResourceGroupName "rg-arclicenses" `
-location "EastUS" `
-state "Deactivated" `
-csvPath ./CreateESULicense.csv 


This example will create a license object that is Deactivated with a virtual cores count of 8 and of type Standard

To modify an existing license object, use the same script while providing different values.
Note that you can only change the NUMBER of cores associated to a license as well as the ACTIVATION state.
You CAN NEITHER modify the EDITION nor can you modify the TYPE of the cores configured for the license.

#>
##############################
#Parameters definition block #
##############################

param(
    [Parameter(Mandatory=$true, HelpMessage="The ID of the subscription where the license will be created.")]
    [ValidatePattern('^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', ErrorMessage="The input '{0}' has to be a valid subscription ID.")]
    [Alias("sub")]
    [string]$subscriptionId,

    [Parameter(Mandatory=$true, HelpMessage="The tenant ID of the Microsoft Entra instance used for authentication.")]
    [ValidatePattern('^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', ErrorMessage="The input '{0}' has to be a valid tenant ID.")]
    [string]$tenantId,

    [Parameter(Mandatory=$false, HelpMessage="Should the license be created activated or deactivated")]
    [ValidateSet('Deactivated','Activated')]
    [string]$licsenseActivationState="Deactivated",

    [Parameter(Mandatory=$true, HelpMessage="The region where the license will be created.")]
    [ValidateNotNullOrEmpty()]
    [Alias("l")]
    [string]$location,

    [Parameter (Mandatory, HelpMessage="File path to the csv containing the license definition")]
    [string] $csvPath

)

#####################################
#End of Parameters definition block #
#####################################


################################
# AZ Login definition block #
################################

Connect-AzAccount
$userToken = Get-AzAccessToken


#########################################
# End of the variables definition block #
#########################################

################################
# Function(s) definition block #
################################
function Import-CSVHash{
    # Check if CSV file exists
    if (-not (Test-Path $csvPath)) {
        Write-Host "CSV file not found, exiting..."
        Exit
    }
    # Import data from CSV file
    else {
        Write-Host "CSV file found, importing..."
        $csv = Import-Csv -Path $csv 
    }

    # Check if CSV file is empty
    if ($null -eq $csv) {
        Write-Host "Mapping file empty, exiting..."
        Exit
    }

    return $csv
}

function New-ESULicenses ($csv) {
    foreach ($line in $csv) {
        $Url = 'https://management.azure.com/subscriptions/' + $line.SubscriptionId + '/resourceGroups/' + $line.ResourceGroup + '/providers/Microsoft.HybridCompute/licenses/' + $line.LicenseName + '?api-version=2023-06-20-preview' 
        $Headers = @{ "Authorization" = "Bearer $token" }
        $Body = @{ 
            "location" = $location
            "properties" = @{
                "licenseDetails" = @{ 
                    "state" = $licsenseActivationState
                    "target" = $line.OS
                    "Edition" = $line.LicenseEdition
                    "Type" = $line.CoreType
                    "Processors" = $line.CoreCount
                }
            }
        } | ConvertTo-Json
        Invoke-RestMethod -Method Put -Uri $Url -Headers $Headers -Body $Body -ContentType "application/json"
    }
}




#######################################
# End of Function(s) definition block #
#######################################


#####################
# Main script block #
#####################

$csv = Import-CSVHash
New-ESULicenses -csv $csv



############################
# End of Main script block #
############################