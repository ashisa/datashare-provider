using namespace System.Net
using namespace Microsoft.AspNetCore.Mvc

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

    $resourceGroup = "datashare0305rg"
    $storageName = "datashare0305storage"
    $dsaccountname = "datashare0305acct"
    $dssharename = "datashare0305"
    $location = "EastUS2"
    $scriptUri = "https://raw.githubusercontent.com/ashisa/datashare-provider/master/consumer/ds-consumer.ps1"
    New-Variable -Scope Script -Name dataset -Value ""

    $ErrorActionPreference = "SilentlyContinue";
    $dsAccount=(Get-AzDataShareAccount -ResourceGroupName $resourceGroup -Name $dsaccountname)
    if (!$dsAccount)
    {
        Write-Host "Creating data share account..."
        $dsAccount=(New-AzDataShareAccount -ResourceGroupName $resourceGroup -Name $dsaccountname -Location $location)

        Write-Host "Assigning contributor role on the storage account for the data share account..."
        $storageAccount=(Get-AzStorageAccount -StorageAccountName $storageName -ResourceGroupName $resourceGroup)
        New-AzRoleAssignment -ObjectId $dsAccount.Identity.PrincipalId -RoleDefinitionName "Storage Blob Data Contributor" -Scope $storageAccount.Id

        Write-Host "Creating data share..."
        New-AzDataShare -ResourceGroupName $resourceGroup -AccountName $dsaccountname -Name $dssharename -Description "From PowerShell" -TermsOfUse "Testing from PowerShell"

        Write-Host "Creating container and dataset..."
        New-AzStorageContainer -Container dataset1 -Context $storageAccount.Context
        $Script:dataset = New-AzDataShareDataSet -ResourcegroupName $resourceGroup -AccountName $dsaccountname -ShareName $dssharename -Name DataSet1 -StorageAccountResourceId $storageAccount.Id -Container dataset1
        Write-Host "$Script:dataset.DataSetId"
    }
    else {
        $Script:dataset = (Get-AzDataShareDataSet -AccountName $dsaccountname -ResourceGroupName $resourceGroup -ShareName $dssharename -Name DataSet1)
    }

    Write-Host "Sending invite..."
    $invite = New-AzDataShareInvitation -ResourceGroupName $resourceGroup -AccountName $dsaccountname -ShareName $dssharename -Name "$invitename" -TargetEmail "$email"
    $inviteID = $invite.InvitationId
    Write-Host "$inviteID"

    Write-Host "Creating ACI instance..."
    $container = New-AzContainerGroup -ResourceGroupName $resourceGroup -Name $invitename -Image docker.io/ashisa/unitty-ds -OsType Linux -IpAddressType Public -Port @(8080) -RestartPolicy Never -Cpu 2 -MemoryInGB 2
    Write-Host "$($container.IpAddress):$($container.Ports)"

    Write-Host "Creating redirect header"
    $url = "http://$($container.IpAddress):$($container.Ports)/?arg=$($scriptUri)&arg=$($inviteID)&arg=$($Script:dataset.Name)&arg=dataset1&arg=$($Script:dataset.DataSetId)"
    Write-Host $url
    $header = ConvertFrom-StringData -StringData $("Location = $($url)")

    $body = "{""inviteID"": ""$($inviteID)"", ""containerName"" : ""dataset1"", ""datasetName"" : ""$($Script:dataset.Name)"", ""datasetID"" : ""$($Script:dataset.DataSetId)""}"
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::Redirect
    ContentType = "application/json"
    Headers = $header
    Body = $body
})
