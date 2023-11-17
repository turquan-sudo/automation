#Requires -Modules az.accounts
<# 
//-----------------------------------------------------------------------

THE SUBJECT SCRIPT IS PROVIDED “AS IS” WITHOUT ANY WARRANTY OF ANY KIND AND SHOULD ONLY BE USED FOR TESTING OR DEMO PURPOSES.
YOU ARE FREE TO REUSE AND/OR MODIFY THE CODE TO FIT YOUR NEEDS

//-----------------------------------------------------------------------

.SYNOPSIS
Manages ESU licenses assignments in bulk, taking its inputs from a CSV file.

.DESCRIPTION
This script manages the assignment of ARC based ESU licenses for servers needing ESU activation.
It retrieves information from a CSV file and the command line for tasks like license assignment and removal.
Its purpose is to allow you to assign a single license to multiple servers at once or to remove a license from multiple servers at once.
Its main targets are servers that are exempted from ESU costs like VMs on Azure VMWare Services or servers that are described in tne following article:
https://learn.microsoft.com/en-us/azure/azure-arc/servers/deliver-extended-security-updates#additional-scenarios

.NOTES
.CHANGELOG
v1.0 - Initial release

.LINK
To get more information on Azure ARC ESU license REST API please visit:
https://learn.microsoft.com/en-us/azure/azure-arc/servers/api-extended-security-updates

.EXAMPLE-1
./ManageESUAssignments -subscriptionId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" `
-location "EastUS" `
-csvFilePath "C:\Temp\ESU Association File.csv"



This example will assign or unassign (unlink) ESU licenses to/from ARC server objects based on the information provided in the CSV file.

You will need to provide the following information in the CSV file:
LicenseName: The name of the ESU license to used.
licenseResourceGroupName: The name of the resource group where the ESU license object is located.
ServerResourceGroupName: The name of the resource group where the ARC server object is located.
ARCServerName: The name of the ARC server object.
AssignESULicense: TRUE or FALSE depending on if you want to assign or unlink the license from the ARC server object.

#>

##############################
#Parameters definition block #
##############################

param(
    [Parameter(Mandatory=$true, HelpMessage="The ID of the subscription where the license will be created.")]
    [ValidatePattern('^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', ErrorMessage="The input '{0}' has to be a valid subscription ID.")]
    [Alias("sub")]
    [string]$subscriptionId,

    [Parameter(Mandatory=$true, HelpMessage="The region where the license will be created.")]
    [ValidateNotNullOrEmpty()]
    [Alias("l")]
    [string]$location,

    [Parameter (Mandatory=$true, HelpMessage="The full path to the CSV file containing the list of ESU eligible resources.")]
    [Alias("csv")]
    [string] $csvFilePath,

    [Parameter(Mandatory=$false, HelpMessage="The name of the log file to be created.")]
    [Alias("log")]
    [string]$logFileName
)

#####################################
#End of Parameters definition block #
#####################################



##############################
# Variables definition block #
##############################

# Do NOT change those variables as it might break the script. They are meant to be static.
$global:creator = $MyInvocation.MyCommand.Name

#########################################
# End of the variables definition block #
#########################################

################################
# AZ Login definition block #
################################

Connect-AzAccount
$userToken = Get-AzAccessToken

################################
# Function(s) definition block #
################################

function AssignESULicense {

    param (
        [string]$bearerToken,
        [string]$licenseResourceGroupName,
        [string]$licenseName,
        [string]$ARCServerName,
        [string]$serverResourceGroupName,
        [string]$location,
        [switch]$unassign
    )

    $apiEndpoint = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$serverResourceGroupName/providers/Microsoft.HybridCompute/machines/$ARCServerName/licenseProfiles/default`?api-version=2023-06-20-preview"
    $licenseID = "/subscriptions/$subscriptionId/resourceGroups/$licenseResourceGroupName/providers/Microsoft.HybridCompute/licenses/$licenseName" 
    $method = "PUT"

    # Sets the headers for the request
    $headers = @{
        "Authorization" = "Bearer $bearerToken"
        "Content-Type" = "application/json"
    }

    # creates the request body depending on the action type (assign or unassign)
    if ($unassign) {
        $requestBody = @{
            location = $location
            properties = @{
                esuProfile = @{
                    
                }
            }
        }
    } 
    else {
        $requestBody = @{
            location = $location
            properties = @{
                esuProfile = @{
                    "assignedLicense" = $licenseID 
                }
            }
        }  
    }


    # Converts the request body to JSON
    $requestBodyJson = $requestBody | ConvertTo-Json -Depth 5

    # Sends the PUT request to update the license
    $response = Invoke-RestMethod -Uri $apiEndpoint -Method $method -Headers $headers -Body $requestBodyJson

    Write-Host ""
    # Sends the response to STDOUT, which would be captured by the calling script if any.
    # Feel free to comment out that line if you don't need to see the response.
    #$response
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

Write-Host ""
Write-Host "=============================================="
Write-Host "Starting ESU license assignments from CSV file"
Write-Host "=============================================="

If (![string]::IsNullOrWhiteSpace($logFileName)) {Start-Transcript -Path $logFileName}

$data = Import-Csv -Path $csvFilePath

foreach ($row in $data) {
         
        #Assign the license to the server if requested from the CSV file (AssignESULicense column shoud say TRUE for assignment or FALSE for unlinking)
        switch ($row.AssignESULicense) {
            "True" {
                Write-Host "Assigning ESU license ("$row.LicenseName") to server ("$row.name")"
                
                $params = @{
                    'subscriptionId' = $subscriptionId
                    'bearerToken' = $userToken.token
                    'licenseResourceGroupName' = $row.licenseResourceGroupName
                    'licenseName' = $row.LicenseName
                    'serverResourceGroupName' = $row.ServerResourceGroupName
                    'ARCServerName' = $row.Name
                    'location' = $location
                }
                
                AssignESULicense @params
              }

            "False" {
                Write-Host "Unlinking ESU license ("$row.LicenseName") from server ("$row.name")"

                $params = @{
                    'subscriptionId' = $subscriptionId
                    'bearerToken' = $bearerToken.token
                    'licenseResourceGroupName' = $row.licenseResourceGroupName
                    'licenseName' = $row.LicenseName
                    'serverResourceGroupName' = $row.ServerResourceGroupName
                    'ARCServerName' = $row.Name
                    'location' = $location
                    'unassign' = $true
                }

                AssignESULicense @params
              }

            Default {
                Write-Host "Missing license assignment action definition for server "$row.name" and license "$row.LicenseName""
                Write-Host ""
            }
        }

    }   
    
      
If (![string]::IsNullOrWhiteSpace($logFileName)) {Stop-Transcript}



############################
# End of Main script block #
############################