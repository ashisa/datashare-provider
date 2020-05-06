using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

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
}
else {
    $body = "Data share account already exists. Please call the invite function to for the consumer setup."
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $body
})
