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
    $Script:dataset = (Get-AzDataShareDataSet -AccountName $dsaccountname -ResourceGroupName $resourceGroup -ShareName $dssharename -Name DataSet1)

    Write-Host "Sending invite..."
    $invite = New-AzDataShareInvitation -ResourceGroupName $resourceGroup -AccountName $dsaccountname -ShareName $dssharename -Name "$invitename" -TargetEmail "$email"
    $inviteID = $invite.InvitationId

    Write-Host "Creating ACI instance..."
    $container = New-AzContainerGroup -ResourceGroupName $resourceGroup -Name $invitename -DnsNameLabel $invitename -Image docker.io/ashisa/unitty-ds -OsType Linux -IpAddressType Public -Port @(8080) -Cpu 2 -MemoryInGB 2

    Write-Host "Creating redirect header"
    $url = "http://$($container.Fqdn):$($container.Ports)/?arg=$($scriptUri)&arg=$($inviteID)&arg=$($Script:dataset.Name)&arg=dataset1&arg=$($Script:dataset.DataSetId)"
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
