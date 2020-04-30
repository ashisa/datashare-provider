using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Interact with query parameters or the body of the request.
$email = $Request.Query.Email
if (-not $email) {
    $email = $Request.Body.Email
}

Write-Host "This HTTP triggered function executed successfully. Pass an email in the query string or in the request body for a personalized response."

if ($email) {
    Write-Host "This HTTP triggered function executed successfully."
    $invitename = $email -replace "@", ""
    $invitename = $invitename -replace "\.", ""

    $resourceGroup = "datashare2704rg"
    $storageName = "datashare2704storage"
    $dsaccountname = "datashare2704acct"
    $dssharename = "datashare2704"
    $location = "EastUS2"

    Write-Host "Creating data share account..."
    $dsAccount=(New-AzDataShareAccount -ResourceGroupName $resourceGroup -Name $dsaccountname -Location $location)

    Write-Host "Assigning contributor role on the storage account for the data share account..."
    $storageAccount=(Get-AzStorageAccount -StorageAccountName $storageName -ResourceGroupName $resourceGroup)
    New-AzRoleAssignment -ObjectId $dsAccount.Identity.PrincipalId -RoleDefinitionName "Storage Blob Data Contributor" -Scope $storageAccount.Id

    Write-Host "Creating data share..."
    New-AzDataShare -ResourceGroupName $resourceGroup -AccountName $dsaccountname -Name $dssharename -Description "From PowerShell" -TermsOfUse "Testing from PowerShell"

    Write-Host "Creating container and dataset..."
    New-AzStorageContainer -Container dataset1 -Context $storageAccount.Context
    $dataset = New-AzDataShareDataSet -ResourcegroupName $resourceGroup -AccountName $dsaccountname -ShareName $dssharename -Name DataSet1 -StorageAccountResourceId $storageAccount.Id -Container dataset1
    Write-Host "$dataset.Id"

    Write-Host "Sending invite..."
    $invite = New-AzDataShareInvitation -ResourceGroupName $resourceGroup -AccountName $dsaccountname -ShareName $dssharename -Name "$invitename" -TargetEmail "$email"
    $inviteID = $invite.InvitationId
    Write-Host "$inviteID"

    $body = "{""inviteID"": ""$($inviteID)"", ""datashareAccount"" : ""$($dsAccount.Name)"", ""containerName"" : ""dataset1"", ""datasetName"" : ""$($dataset.Name)"", ""datasetID"" : ""$($dataset.DataSetId)""}"
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $body
})
