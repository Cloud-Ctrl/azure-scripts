$ErrorActionPreference = "Stop"
$servicePrincipalId = $null
do{
    $appName = Read-Host -Prompt "What is the Application Name created in Azure AD?"
    $servicePrincipalId = (Get-AzADServicePrincipal -DisplayName $appName).id
    if(!$servicePrincipalId)
    {
        Write-Host "Can't find Application with name $($appName)" -ForegroundColor Yellow
    }
}while(!$servicePrincipalId)
$location = Read-Host -Prompt "Enter an Azule location (i.e. australiaeast) where the role template will be deployed:"
$templateUri = "https://raw.githubusercontent.com/Cloud-Ctrl/azure-scripts/main/role-templates/cc-readOnly.json"

$roleName = Read-Host -Prompt "Enter a name for the new custom role definition:"

# Get the list of subscriptions visible to the current user
$subscriptions = Get-AzSubscription | Where-Object { $_.State -eq "Enabled" }

# Initialize an array to store the subscriptions with write permission action to Microsoft.Authorization/roledefinitions
$assignableScopes = @()

# Loop through each subscription and check if it has write permission to Microsoft.Authorization role definitions
foreach ($subscription in $subscriptions) {
    $assignableScopes += "/subscriptions/" + $subscription.Id
}

try{
    # Define the parameters for the custom role
    $params = @{
        scopes = $assignableScopes
        roleName = $roleName
    }
    New-AzDeployment -Location $location -TemplateUri $templateUri -TemplateParameterObject $params | out-null
    Write-Host "> Custom role has been deployed" -ForegroundColor Green   
}catch{
    Write-Host "Failed to deploy role definition from template" -ForegroundColor Red
    Write-Output $_
}

# Assign the role to the Service Principal
foreach ($subscription in $subscriptions) {
    try{
        New-AzRoleAssignment -ObjectId $servicePrincipalId -RoleDefinitionName $roleName -Scope "/subscriptions/$($subscription.id)" | out-null
        Write-Host "> Role Assigned to Service Principal for Subscription $($subscription.Name)" -ForegroundColor Green
    }catch{
        Write-Host "Failed to assign role in Subscription $($subscription.Name)" -ForegroundColor Red
        Write-Output $_
    }
}