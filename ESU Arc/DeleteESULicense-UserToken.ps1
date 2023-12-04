<# 
//-----------------------------------------------------------------------

THE SUBJECT SCRIPT IS PROVIDED “AS IS” WITHOUT ANY WARRANTY OF ANY KIND AND SHOULD ONLY BE USED FOR TESTING OR DEMO PURPOSES.
YOU ARE FREE TO REUSE AND/OR MODIFY THE CODE TO FIT YOUR NEEDS

//-----------------------------------------------------------------------

.SYNOPSIS
Deletes an ESU license used in Azure ARC.

.DESCRIPTION
This script will delete an existing ARC based ESU license.
License deletion should only be done when it is not required anymore and cannot be reused for another ARC server.
Deleting a license will sever the association between that license and the ARC server object previously linked to it.
Deleting a license will stop the monthly billing for the ESU associated with that license.

.NOTES
File Name : DeleteESULicense-UserToken.ps1
Author    : Jason Bank
Version   : 1.1
Date      : 19-October-2023
Update    : 4-December-2023
Tested on : PowerShell Version 7.3.8
Module    : Azure Powershell version 9.6.0
Requires  : Powershell Core version 7.x or later
Product   : Azure ARC

.LINK
To get more information on Azure ARC ESU license REST API please visit:
https://learn.microsoft.com/en-us/azure/azure-arc/servers/api-extended-security-updates

.EXAMPLE-1
./DeleteESULicense -subscriptionId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" `
-tenantId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" `
-appID "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" `
-clientSecret "your_application_secret_value" `
-csvFilePath "C:\Temp\ESU Eligible Resources.csv" `

.EXAMPLE-2
./DeleteESULicense -subscriptionId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" `
-userToken $token`
-csvFilePath "C:\Temp\ESU Eligible Resources.csv" `


This example will create a license object that is Deactivated with a virtual cores count of 8 and of type Standard

To modify an existing license object, use the same script while providing different values.
Note that you can only change the NUMBER of cores associated to a license as well as the ACTIVATION state.
You CAN NEITHER modify the EDITION nor can you modify the TYPE of the cores configured for the license.

You can now provide a user token object to the script instead of the appID, clientSecret and tenantId parameters.
Create the token object by running the following command in PowerShell:
$token = Get-AzAccessToken
and pass that $token object as part of the command line parameters.

#>
##############################
#Parameters definition block #
##############################

param(
    [Parameter(Mandatory=$true, HelpMessage="The ID of the subscription where the license will be created.")]
    [ValidatePattern('^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', ErrorMessage="The input '{0}' has to be a valid subscription ID.")]
    [string]$subscriptionId,

    [Parameter(Mandatory=$false, HelpMessage="The tenant ID of the Microsoft Entra instance used for authentication.")]
    [ValidatePattern('^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', ErrorMessage="The input '{0}' has to be a valid tenant ID.")]
    [string]$tenantId,

    [Parameter(Mandatory=$false, HelpMessage="The application (client) ID as shown under App Registrations that will be used to authenticate to the Azure API.")]
    [ValidatePattern('^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', ErrorMessage="The input '{0}' has to be a valid application ID.")]
    [string]$appID,

    [Parameter(Mandatory=$false, HelpMessage="A valid (non expired) client secret for App Registration that will be used to authenticate to the Azure API.")]
    [Alias("secret","s")]
    [string]$clientSecret,

    [Parameter (Mandatory=$true, HelpMessage="The full path to the CSV file containing the list of ESU eligible resources.")]
    [Alias("csv")]
    [string] $csvFilePath
)

#####################################
#End of Parameters definition block #
#####################################

################################
# AZ Login definition block #
################################

Connect-AzAccount
$userToken = Get-AzAccessToken


##############################
# Variables definition block #
##############################

# Do NOT change those variables as it will break the script. They are meant to be static.
# Azure API endpoint
$method = "DELETE"

#########################################
# End of the variables definition block #
#########################################



################################
# Function(s) definition block #
################################

function Get-AzureADBearerToken {
    param(
        [string]$appID,
        [string]$clientSecret,
        [string]$tenantId
    )

    # Defines token authorization endpoint
    $oAuthEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/token"

    # Builds the request body
    $authbody = @{
        grant_type = "client_credentials"
        client_id = $appID
        client_secret = $clientSecret
        resource = "https://management.azure.com/"
    }
    
    # Obtains the token
    Write-Verbose "Authenticating..."
    try { 
            $response = Invoke-WebRequest -Method Post -Uri $oAuthEndpoint -ContentType "application/x-www-form-urlencoded" -Body $authbody
            $accessToken = ($response.Content | ConvertFrom-Json).access_token
            return $accessToken
    }
    
    catch { 
        Write-Error "Error obtaining Bearer token: $_"
        return $null
     }    
}

function Write-Logfile  {
    param(
    [Parameter (Mandatory=$true)]
    [Alias("m")]
    [string] $message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output ("[$timestamp] " + $message)
}

#######################################
# End of Function(s) definition block #
#######################################



#####################
# Main script block #
#####################

# Check if the token is still valid
if ($userToken) {
    if ($userToken.ExpiresOn -gt (Get-Date)) {
        Write-Host "Using provided Microsoft Entra ID authentication token"
        $token = $userToken.Token
    } else {
        Write-Host "The provided user token has expired. Please provide a valid token.`nExiting."
        exit
    }
} elseif ($tenantId -and $appID -and $clientSecret) {
    Write-Host "Getting authentication token from Microsoft Entra ID"
    $token = Get-AzureADBearerToken -appID $appID -clientSecret $clientSecret -tenantId $tenantId 
} else {
    Write-Host "You need to provide either the tenant, appID and clientSecrets parameters or a valid authentication token object.`nExiting."
    exit
}

# Sets the headers for the request
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

# Sends the PUT request to update the license

Write-Host ""
Write-Host "==========================================="
Write-Host "Starting ESU license deletion from CSV file"
Write-Host "==========================================="

If (![string]::IsNullOrWhiteSpace($logFileName)) {Start-Transcript -Path $logFileName}

$data = Import-Csv -Path $csvFilePath

foreach ($row in $data) {
    $response = Invoke-RestMethod -Uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$($row.ResourceGroupName)/providers/Microsoft.HybridCompute/licenses/$($row.licenseName)`?api-version=2023-10-03-preview" `
                                  -Method $method `
                                  -Headers $headers  

    Write-Host " Removing License $($row.licenseName)"
}

If (![string]::IsNullOrWhiteSpace($logFileName)) {Stop-Transcript}

# Sends the response to STDOUT, which would be captured by the calling script if any
$response

############################
# End of Main script block #
############################