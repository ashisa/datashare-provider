$resourceGroup = "datashare0305rg"
$storageName = "datashare0305cstorage"
$dsaccountName = "datashare0305acct"
$location = "EastUS2"
$inviteID =  $args[0]
$dsshareName = $args[1]
$dsContainer = $args[2]
$datasetId = $args[3]

Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

Write-Host ""
Write-Host "Initiating Azure Data Share service provisioning..."
Write-Host ""
Write-Host "Please follow the instructions below to connect to your Azure subscription."
Write-Host ""
Write-Host "Connecting to Azure subscription..."
(Connect-AzAccount -UseDeviceAuthentication) | Out-Null

Write-Host "Creating resource group..." -NoNewline
(New-AzResourceGroup -Name $resourceGroup -Location $location) |Out-Null
Write-Host "Done."

Write-Host "Creating data share account..." -NoNewline
($dsAccount=New-AzDataShareAccount -ResourceGroupName $resourceGroup -Name $dsaccountName -Location $location) |Out-Null
Write-Host "Done."

Write-Host "Assigning contributor role on the storage account for the data share account..." -NoNewline
($storageAccount=New-AzStorageAccount -StorageAccountName $storageName -ResourceGroupName $resourceGroup -Location $location -SkuName Standard_LRS)  |Out-Null
New-AzRoleAssignment -ObjectId $dsAccount.Identity.PrincipalId -RoleDefinitionName "Storage Blob Data Contributor" -Scope $storageAccount.Id  |Out-Null
Write-Host "Done."

Write-Host "Creating container..." -NoNewline
(New-AzStorageContainer -Container dataset1 -Context $storageAccount.Context) |Out-Null
Write-Host "Done."

Write-Host "Accepting the invite..." -NoNewline
(New-AzDataShareSubscription -ResourceGroupName $resourceGroup -AccountName $dsaccountName -Name $dsshareName -SourceShareLocation $location -InvitationId $inviteID)  |Out-Null
Write-Host "Done."

Write-Host "Creating DataSet mapping..." -NoNewline
(New-AzDataShareDataSetMapping -ResourceGroupName $resourceGroup -AccountName $dsaccountName -StorageAccountResourceId $storageAccount.Id -Container $dsContainer -Name $dsshareName -ShareSubscriptionName $dsshareName -DataSetId $datasetId) |Out-Null
Write-Host "Done."

Write-Host "Starting initial snapshot in the background..." -NoNewline
(Start-AzDataShareSubscriptionSynchronization -ResourceGroupName $resourceGroup -AccountName $dsaccountName -ShareSubscriptionName $dsshareName -SynchronizationMode FullSync  -AsJob)  |Out-Null
Write-Host "Done."

Write-Host "Azure Data Share service provisioning succeeded."
Write-Host "You can close this window and visit Azure portal to verify the Azure Data Share service status."
