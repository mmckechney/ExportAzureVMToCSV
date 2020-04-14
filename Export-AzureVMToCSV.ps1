param(
    [string]$subscriptionId="",
    [string]$file="Azure-VMs.csv",
    [string]$tenantID=""
) 


if ($subscriptionId -eq "") 
{
    Write-Host "Subscription Id is missing."
    $subscriptionId = Read-Host -Prompt "Please provide the Azure subscription ID:"    
} 
else 
{
    Write-Host "Subscription Id selected is: "  $subscriptionId
}

if ($tenantID -eq "") 
{
    Write-Host "Azure AD Tenant Id is missing."
    $tenantID = Read-Host -Prompt "Please provide the Azure Ad Tenant ID:"    
} 
else 
{
    Write-Host "Azure Ad Tenant Id selected is: "  $tenantID
}


#Write-host "Disconnecting already cached accounts."
#Disconnect-AzAccount

#prompt for login to Azure account
Write-Host "Login to Azure account who has the access to read Azure VM information".
#Connect-AzAccount -Tenant $tenantID

#get the subscription details
$sub = Get-AzSubscription -SubscriptionId $subscriptionId -ErrorAction Continue
Select-AzSubscription -SubscriptionId $subscriptionId -ErrorAction Continue

#declare VM object variable
$vmobjects = @()

Write-Host Retrieving Azure VMs from subscription $sub.SubscriptionName


class VMInformation {
    [string]$SubscriptionName
    [string]$VMName
    [string]$ResourceGroupName
    [string]$Location
    [string]$VMSize
    [string]$Status
    [string]$AvailabilitySet
    [string]$PrivateIP
    [string]$PublicIPName
    [string]$PublicIPAddress
    [string]$OSType
    [string]$PrimaryNICName
    [string]$NSGName
    [string]$Subnet
    [string]$VNETName
}


#retrive all VMs in subscription
$vms = Get-AzVM -Status
try
    {
        foreach ($vm in $vms)
        {
            Write-Output $vm.Name
            #retrive the Network configuration of VM
            $allNicNames = @()
            $allPrivateIps = @()
            $allPublicIps = @()
            $allPublicIpNames = @()
            $allNSGs = @()
            $allSubNets = @()
            $allVnets = @()
            $nics = $vm.NetworkProfile.NetworkInterfaces
            foreach($nic in $nics)
            {
                $currentNic = Get-AzNetworkInterface -ResourceId $nic.Id
                $allNicNames += $currentNic.Name
                $ipConfigs = $currentNic.IpConfigurations
                foreach($ipConfig in $ipConfigs )
                {
                    $allPrivateIps += $ipConfigs.PrivateIpAddress
                    if($null -eq $ipConfig.PublicIpAddress.Id)
                    {
                        $allPublicIpNames += "No PublicIP"
                    }
                    else
                    {
                        $tmpPubIp = $ipConfig.PublicIpAddress.Id.Substring($ipConfig.PublicIpAddress.Id.LastIndexOf("/")+1) 
                        $allPublicIpNames +=$tmpPubIp 
                        $tmpAddress = Get-AzPublicIpAddress -Name $tmpPubIp -ResourceGroupName $currentNic.ResourceGroupName  #Assumes that Public IP is in the same RG as the NIC
                        if($null -ne $tmpAddress.IpAddress)
                        {
                            $allPublicIps += $tmpAddress.IpAddress
                        } 
                    }
                   
                    $tmpSubNet = $ipConfig.Subnet
                    $allSubNets += (Get-AzVirtualNetworkSubnetConfig -ResourceId $tmpSubNet.Id).Name


                    $tempString = $tmpSubNet.Id.Substring($tmpSubNet.Id.IndexOf("virtualNetworks"))
                    $t = $tempString.Remove($tempString.IndexOf("/subnets"))
                    $allVnets += $t.Substring($t.IndexOf("/") + 1)
                }

                $nsgId = $currentNic.NetworkSecurityGroup.Id
                if($null -eq $nsgId)
                {
                    $allNSGs += "No NSG"
                }
                else
                {
                    $allNSGs += $nsgId.Substring($nsgId.LastIndexOf("/")+1)
                }
            }
          
            
            if($null -eq $vm.AvailabilitySetReference.Id)
            {
                $availabiltySet = "None"
            }
            else
            {
                $availabiltySet = $vm.AvailabilitySetReference.Id.Substring($vm.AvailabilitySetReference.Id.LastIndexOf("/")+1)
            }

            $vmInfo = [VMInformation]@{
                SubscriptionName = $sub.Name;
                VMName = $vm.Name;
                ResourceGroupName = $vm.ResourceGroupName;
                Location = $vm.Location;
                VMSize = $vm.HardwareProfile.VMSize;
                Status = $vm.PowerState;
                AvailabilitySet = $availabiltySet;
                PrivateIP = $allPrivateIps  -join ",";
                PublicIPName  = $allPublicIpNames  -join ",";
                PublicIPAddress = $allPublicIps -join ",";
                OSType = $vm.StorageProfile.OsDisk.OsType;
                PrimaryNICName = $allNicNames -join ",";
                NSGName = $allNSGs -join ",";
                Subnet = $allSubNets -join ",";
                VNETName = $allVnets -join ",";}

            $vmobjects += $vmInfo
        }  
    }
    catch
    {
        Write-Host $error[0]
    }


$vmobjects | Export-Csv -NoTypeInformation -Path $file
Write-Host "VM list written to $file"


