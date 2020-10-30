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
    $VirtualMachineSize

)


$VirtualMachineCounts = $VirtualMachineNameArray.Count

Write-Host "Total Virtual Machine(s): $VirtualMachineCounts"

$Progress = 0

$AzSecureApplicationKey = $AppKey | ConvertTo-SecureString -AsPlainText -Force

$AzCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ClientId, $AzSecureApplicationKey

[bool]$isAzConnected = [bool](Connect-AzAccount -Credential $AzCredential -TenantId $TenantId -ServicePrincipal)

if($isAzConnected){
   
    foreach($VirtualMachine in $VirtualMachineNameArray){
        $ResourceGroupName = (Get-AzResource -Name $VirtualMachine -ResourceType "Microsoft.Compute/virtualMachines").ResourceGroupName
        Write-Host "Resizing $VirtualMachine"
        Stop-AzVM -ResourceGroupName $ResourceGroupName -Name $VirtualMachine -Force
        $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -VMName $VirtualMachine
        $vm.HardwareProfile.VmSize = $VirtualMachineSize
        Update-AzVM -VM $vm -ResourceGroupName $ResourceGroupName
        $Progress = $Progress + 1
        Write-Host "$Progress out of $VirtualMachineCounts"

    }
    Write-Host "Done"

}
else{
    throw("Authentication Failed")
}