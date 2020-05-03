$resourceGroup = "datashare0305rg"
$storageName = "datashare0305storage"
$dsaccountName = "datashare0305acct"
$location = "EastUS2"
$inviteID =  $args[0]
$dsshareName = $args[1]
$dsContainer = $args[2]
$datasetId = $args[3]

Write-Host "Connecting to Azure subscription..."
Connect-AzAccount

Write-Host "Creating resource group..."
New-AzResourceGroup -Name $resourceGroup -Location $location

Write-Host "Creating data share account..."
$dsAccount=(New-AzDataShareAccount -ResourceGroupName $resourceGroup -Name $dsaccountName -Location $location)

Write-Host "Assigning contributor role on the storage account for the data share account..."
$storageAccount=(New-AzStorageAccount -StorageAccountName $storageName -ResourceGroupName $resourceGroup -Location $location -SkuName Standard_LRS)
New-AzRoleAssignment -ObjectId $dsAccount.Identity.PrincipalId -RoleDefinitionName "Storage Blob Data Contributor" -Scope $storageAccount.Id

Write-Host "Creating containers..."
New-AzStorageContainer -Container dataset1 -Context $storageAccount.Context

Write-Host "Accepting the invite..."
New-AzDataShareSubscription -ResourceGroupName $resourceGroup -AccountName $dsaccountName -Name $dsshareName -SourceShareLocation $location -InvitationId $inviteID

Write-Host "Creating DataSet mapping..."
New-AzDataShareDataSetMapping -ResourceGroupName $resourceGroup -AccountName $dsAccount.Name -StorageAccountResourceId $storageAccount.Id -Container $dsContainer -Name $dsshareName -ShareSubscriptionName $dsshareName -DataSetId $datasetId

Write-Host "Starting initial snapshot in the background..."
Start-AzDataShareSubscriptionSynchronization -ResourceGroupName $resourceGroup -AccountName $dsaccountName -ShareSubscriptionName $dsshareName -SynchronizationMode FullSync  -AsJob
