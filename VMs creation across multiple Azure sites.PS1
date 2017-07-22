cd\
clear

#VMs Creation across multiple Azure sites

#Logging into Azure account (ARM Mode) and selecting Microsoft Sponsored subscription to be the default deployment account
Login-AzureRmAccount

#Automated offline logon script for subsequent Azure connection
#Save-AzureRmProfile -Path <Drive\Path\azurermprofile.json>
#Select-AzureRmProfile -Path <Drive\Path\azurermprofile.json> #This must be created prior to run. More information at https://4sysops.com/archives/auto-login-to-azure-with-powershell/ 

Get-AzureRmSubscription
Select-AzureRmSubscription -SubscriptionName <'Registered subscription name'> -TenantId <alphanumeric code>

#Record existing powershell ISE environment variables
$ExistingVariables = Get-Variable | Select-Object -ExpandProperty Name

$NumberOfVM = 1; #This identifies the number Virtual Machines to be created during this loop
$SN = -1; #This represents the specific Subnet identifier, hence initialized as a negative integer
$IDs = 0; #This represents an independent resource group or resource identifier, across regions

$uName="AzAdmin"
$password = cat <Drive\Path\mysecurestring.txt> | convertto-securestring
$credVM = new-object -typename System.Management.Automation.PSCredential -ArgumentList "$uName$NumberOfVM", $password

While ($NumberOfVM -le 3) #This represents the number of time this overall loop will iterate
{ 
    ##Resource Group
    $rgName = "AzrSvc"
    
    ##Network
    $vnetName = 'AzrTrngVnet'

    ##Storage
    $storaccName = "azrtrngstg"

    ##Virtual Machine
    $vmName = 'AzrTrngVM'

    ##Availability Set
    #$avlstName = 'AzrAvlSt'

    If ($NumberOfVM -eq 1)
    {
        ##Location Preference
        $location = Get-AzureRmLocation|Where-Object{$_.DisplayName -match 'West US 2'}
        $locationName = $location.DisplayName

        ##Network
        $addPrfx = '10.0.0.0/8'
        $snetName1 = 'Web'
        $snetName2 = 'Logic'
        $snetName3 = 'Data'
        $snetName4 = 'Support'
        $saddPrfx1 = '10.1.0.0/16'
        $saddPrfx2 = '10.2.0.0/16'
        $saddPrfx3 = '10.3.0.0/16'
        $saddPrfx4 = '10.4.0.0/16'
    }            
        
    ElseIf ($NumberOfVM -eq 2)
    {
        ##Location Preference
        $location = Get-AzureRmLocation|Where-Object{$_.DisplayName -match 'East US 2'}
        $locationName = $location.DisplayName

        ##Network
        $addPrfx = '172.16.0.0/16'
        $snetName1 = 'Web'
        $snetName2 = 'Logic'
        $snetName3 = 'Data'
        $snetName4 = 'Support'
        $saddPrfx1 = '172.16.1.0/24'
        $saddPrfx2 = '172.16.2.0/24'
        $saddPrfx3 = '172.16.3.0/24'
        $saddPrfx4 = '172.16.4.0/24'
    }            
        
    ElseIf ($NumberOfVM -eq 3)
    {
        ##Location Preference
        $location = Get-AzureRmLocation|Where-Object{$_.DisplayName -match 'UK West'}
        $locationName = $location.DisplayName
              
        ##Network
        $addPrfx = '172.17.0.0/16'
        $snetName1 = 'Web'
        $snetName2 = 'Logic'
        $snetName3 = 'Data'
        $snetName4 = 'Support'
        $saddPrfx1 = '172.17.1.0/24'
        $saddPrfx2 = '172.17.2.0/24'
        $saddPrfx3 = '172.17.3.0/24'
        $saddPrfx4 = '172.17.4.0/24'
    }
    
    <#---If ($NumberOfVM -eq 1 -or $NumberOfVM -eq 3 -or $NumberOfVM -eq 5)---#>
    If ($NumberOfVM -eq 1 -or $NumberOfVM -eq 2 -or $NumberOfVM -eq 3)
    {
    ##Resource Group, if resource group has been created comment this out.
    $IDs++
    $rgName = "$rgName$IDs"
    $rg = New-AzureRmResourceGroup -Name $rgName -Location $locationName -Tag @{Creator="Your Name";Company="Organization Name";Dept="Department Name";Division="Division Name"}
    
    ##Availability Group
    #$avlSet = New-AzureRmAvailabilitySet -Name "${avlstName}1" -ResourceGroupName $rgName -Location $locationName -PlatformFaultDomainCount 2 -PlatformUpdateDomainCount 2 -Verbose

    ##Compute
    $vmSizes = Get-AzureRmVMSize -Location $locationName |where{$_.Name -ccontains 'Standard_A2'}
    $vmszName = $vmSizes.Name
    
    ##Subnets
    $snet1 = New-AzureRmVirtualNetworkSubnetConfig -Name $snetName1 -AddressPrefix $saddPrfx1
    $snet2 = New-AzureRmVirtualNetworkSubnetConfig -Name $snetName2 -AddressPrefix $saddPrfx2
    $snet3 = New-AzureRmVirtualNetworkSubnetConfig -Name $snetName3 -AddressPrefix $saddPrfx3
    $snet4 = New-AzureRmVirtualNetworkSubnetConfig -Name $snetName4 -AddressPrefix $saddPrfx4
    $snets = $snet1,$snet2,$snet3,$snet4
    $vnetName = $vnetName + $IDs
    $vnet = New-AzureRmVirtualNetwork -Name $vnetName -AddressPrefix $addPrfx -Subnet $snets -ResourceGroupName $rgName -Location $locationName
    
    $snetId = $vnet.Subnets[$SN++].Id

    ##Setup Storage Account
    $storaccName = $storaccName + $IDs
    $storaccType = @("Standard_LRS", "Standard_ZRS", "Standard_GRS", "Standard_RAGRS", "Premium_LRS")
    $storacct = New-AzureRmStorageAccount -Name $storaccName -ResourceGroupName $rgName -SkuName $storaccType[0] -Location $locationName -Kind Storage
    
    ##Setup local VM object
    $vmName = $vmName + $NumberOfVM
    $disknameOS = $vmName +'diskOS'
    $vhduri = $storacct.PrimaryEndpoints.Blob + 'vhds/' + $disknameOS + '.vhd'
    $nic = New-AzureRmNetworkInterface -Name $vmName"_nic1" -Location $locationName -ResourceGroupName $rgName -SubnetId $snetId
    }

    Else
    {
    $rgName = (Get-AzureRmResourceGroup -Location $locationName).ResourceGroupName
    #$avlstName = (Get-AzureRmAvailabilitySet -ResourceGroupName $rgName).Name
    $vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $rgName
    $storacct = Get-AzureRmStorageAccount -ResourceGroupName $rgName
    $disknameOS = "${vmName}diskOS"
    $vhduri = $storacct.PrimaryEndpoints.Blob + 'vhds/' + $disknameOS + '.vhd'
    $vmName="$vmName$NumberOfVM"
    $nic = New-AzureRmNetworkInterface -Name $vmName"_nic1" -Location $locationName -ResourceGroupName $rgName -SubnetId $snetId
    }

    ##Create the VM in Azure
    $pubs = (Get-AzureRmVMImagePublisher -Location $locationName)|Where-Object{$_.PublisherName -match 'WindowsServer'}
    $pub = $pubs.Item(0)
    $pubName = $pub.PublisherName
    $offrs = (Get-AzureRmVMImageOffer -Location $locationName -PublisherName $pubName)|Where-Object{$_.Offer -ceq 'WindowsServer'}
    $offrName = $offrs.Offer
    $imgsku = (Get-AzureRmVMImageSku -Location $locationName -PublisherName $pubName -Offer $offrName)|Where-Object{$_.Skus -match '2012-R2'}
    $imgskuname = $imgsku.Skus[0]
    $imagesRM = Get-AzureRmVMImage -Location $locationName -PublisherName $pubName -Offer $offrName -Skus $imgskuname| Sort-Object -Property Version -Descending
    $imgName = $imagesRM.Item(0).Version
    
    #$newVM = New-AzureRmVMConfig -VMName $vmName -VMSize $vmszName -AvailabilitySetId $avlSet.Id
    $newVM = New-AzureRmVMConfig -VMName $vmName -VMSize $vmszName
    Add-AzureRmVMNetworkInterface -VM $newVM -Id $nic.Id
    Set-AzureRmVMOperatingSystem -Windows -VM $newVM -ProvisionVMAgent -EnableAutoUpdate -Credential $credVM -ComputerName $vmName
    Set-AzureRmVMSourceImage -VM $newVM -PublisherName $pubName -Offer $offrName -Skus $imgskuname -Version $imgName
    Set-AzureRmVMOSDisk -VM $newVM -Name $disknameOS-VhdUri $vhduri -Caching ReadWrite -CreateOption FromImage
    New-AzureRmVM -ResourceGroupName $rgName -Location $locationName -VM $newVM -Verbose
$NumberOfVM++
}

#Clearing variables other than the recorded (pre-existing) environment variables
$NewVariables = Get-Variable | Select-Object -ExpandProperty Name | Where-Object {$ExistingVariables -notcontains $_ -and $_ -ne "ExistingVariables"}
if ($NewVariables)
    {
    Write-Host "Removing the following variables:`n`n$NewVariables"
    Remove-Variable $NewVariables
    }
else
    {
    Write-Host "No new variables to remove!"
    }
