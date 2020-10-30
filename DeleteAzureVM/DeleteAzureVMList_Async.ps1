Param(
    [Parameter(Mandatory=$true)]
    [string] 
    $TenantId,
    
    [Parameter(Mandatory=$true)]
    [string] 
    $ClientId,
    
    [Parameter(Mandatory=$true)]
    [string] 
    $AppKey,
    
    [Parameter(Mandatory=$true)]
    [string] 
    $SubscriptionId,
    
    [Parameter(Mandatory=$true)]
    [Array] 
    $VirtualMachineNameArray,
    
    [Parameter(Mandatory=$true)]
    [string] 
    $StorageAccountName,
    
    [Parameter(Mandatory=$false)]
    [switch] 
    $IncludeVHD

)

$AzSecureApplicationKey = $AppKey | ConvertTo-SecureString -AsPlainText -Force

$AzCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ClientId, $AzSecureApplicationKey

[bool]$isAzConnected = [bool](Add-AzAccount -Credential $AzCredential -TenantId $TenantId -Subscription $SubscriptionId -ServicePrincipal)

# Function for generating file name.
function Generate-FileName{

    $DateNow = [DateTime]::Now
    $Year = $DateNow.Year
    $MonthString = $DateNow.ToString("MMMM")
    $DayString = $DateNow.ToString("dddd")
    $Day = $DateNow.Day
    
    $Month = Add-Zero -Number $DateNow.Month
    $Hour = Add-Zero -Number $DateNow.Hour
    $Minute = Add-Zero -Number $DateNow.Minute
    $Second = Add-Zero -Number $DateNow.Second

    return "$DayString $Day $MonthString $Year $Hour$Minute$Second"
}

# Adding zero to have a 2 digit number
function Add-Zero{

    param($Number)
    
    if($Number -le 9){
        return '0' + $Number.ToString()
    }
    else{
        return $Number.ToString()
    }
}

class VirtualMachine{
    
    [string]$VirtualMachineName
    [string]$PublicIPAddressName
    [string]$NetworkInterfaceName
    [string]$VirtualHardDiskName
    [string]$ResourceGroupName

}

$DeletedVirtualMachines = New-Object System.Collections.Generic.List[VirtualMachine]
$VirtualMachinesCount = 0
$includeVHD = $IncludeVHD.IsPresent

if($isAzConnected){
    
    if($VirtualMachineNameArray.Count -ne 0){
        
        foreach($VirtualMachine in $VirtualMachineNameArray){
        
            $DeletedVirtualMachine = New-Object VirtualMachine
            $VirtualMachineName = $VirtualMachine
            $PublicIPAddressName = "IP-"+$VirtualMachine
            $NetworkInterfaceName = $VirtualMachine
            
            Write-Host " "
            Write-Host "VM:" $VirtualMachineName
            Write-Host "IP:" $PublicIPAddressName
            Write-Host "NI:" $NetworkInterfaceName

            $ResourceGroupName = (Get-AzResource -Name $VirtualMachineName -ResourceType "Microsoft.Compute/virtualMachines").ResourceGroupName

            Write-Host $ResourceGroupName

            $VhdResourceGroupName = (Get-AzResource -Name $StorageAccountName -ResourceType "Microsoft.Storage/storageAccounts").ResourceGroupName

            $VMName = $VirtualMachineName

            $SA = Get-AzStorageAccount -ResourceGroupName $VhdResourceGroupName -Name $StorageAccountName

            $UMD = $SA | Get-AzStorageContainer | Get-AzStorageBlob | Where {$_.Name -like '*.vhd'}

            $UMVHDS = $UMD | Where {$_.Name -like "*$VMName*.vhd" }

            $UMVHDS.Name

            $VirtualMachinesCount = $VirtualMachinesCount + 1
            
            Write-Host "$VirtualMachinesCount out of" $VirtualMachineNameArray.Count

            Write-Host "-------------------"

            Start-Job -ScriptBlock {
                [bool](Add-AzAccount -Credential $args[0] -TenantId $args[1] -Subscription $args[8] -ServicePrincipal)
                $isExisting = [bool](Get-AzVM -ResourceGroupName $args[2] -Name $args[3] -ErrorAction Ignore) -or 
                            [bool](Get-AzPublicIpAddress -ResourceGroupName $args[2] -Name $args[4] -ErrorAction Ignore) -or
                            [bool](Get-AzNetworkInterface -ResourceGroupName $args[2] -Name $args[5] -ErrorAction Ignore)
                
                Write-Host $isExisting

                While($isExisting){
                    if($isExisting){
                        Write-Host "Deleting."
                        Remove-AzVM -ResourceGroupName $args[2] -Name $args[3] -Force -ErrorAction Ignore
                        Remove-AzPublicIpAddress -ResourceGroupName $args[2] -Name $args[4] -Force -ErrorAction Ignore
                        Remove-AzNetworkInterface -ResourceGroupName $args[2] -Name $args[5] -Force -ErrorAction Ignore
                    }
                    else{
                        Write-Host "Deleted."
                    }
                    $isExisting = [bool](Get-AzVM -ResourceGroupName $args[2] -Name $args[3] -ErrorAction Ignore) -or 
                            [bool](Get-AzPublicIpAddress -ResourceGroupName $args[2] -Name $args[4] -ErrorAction Ignore) -or
                            [bool](Get-AzNetworkInterface -ResourceGroupName $args[2] -Name $args[5] -ErrorAction Ignore)
                }
        
                if($args[7]){
            
                    $vhdResourceGroupName = (Get-AzResource -Name $args[6] -ResourceType "Microsoft.Storage/storageAccounts").ResourceGroupName

                    $storageAccountName = $args[6]

                    $VMName = $args[3]

                    $ResourceGroupName = $args[2]

                    $SA = Get-AzStorageAccount -ResourceGroupName $vhdResourceGroupName -Name $storageAccountName

                    $UMD = $SA | Get-AzStorageContainer | Get-AzStorageBlob | Where {$_.Name -like '*.vhd'}

                    $UMVHDS = $UMD | Where {$_.ICloudBlob.Properties.LeaseStatus -eq "Unlocked" -and $_.Name -like "*$VMName*.vhd" }

                    $UMVHDS

                    $UMVHDS | Remove-AzStorageBlob
                }

                Write-Host $args[5]

            } -ArgumentList $AzCredential, $TenantId, $ResourceGroupName, $VirtualMachineName, $PublicIPAddressName, $NetworkInterfaceName, $StorageAccountName, $IncludeVHD, $SubscriptionId
                            #$args[0]      $args[1]   $args[2]            $args[3]             $args[4]              $args[5]               $args[6]             $args[7]     $args[8]
            Start-Sleep -Seconds 1

            $DeletedVirtualMachine.VirtualMachineName = $VirtualMachineName
            $DeletedVirtualMachine.PublicIPAddressName = $PublicIPAddressName
            $DeletedVirtualMachine.NetworkInterfaceName = $NetworkInterfaceName
            $DeletedVirtualMachine.ResourceGroupName = $ResourceGroupName
            $DeletedVirtualMachine.VirtualHardDiskName = $UMVHDS.Name
                    
            $DeletedVirtualMachines.Add($DeletedVirtualMachine)

        }

        Get-Job | Wait-Job | Receive-Job 
        
        Get-Job | Remove-Job

        Write-Host "Done!"

    }
    else{

        Write-Host "No VM Found"
    
    }

}
else{

    Write-Host "Failed to login"

}