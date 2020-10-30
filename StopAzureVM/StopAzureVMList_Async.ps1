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
    $VirtualMachineNameArray

)

$AzSecureApplicationKey = $AppKey | ConvertTo-SecureString -AsPlainText -Force

$AzCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ClientId, $AzSecureApplicationKey

[bool]$isAzConnected = [bool](Connect-AzAccount -Credential $AzCredential -TenantId $TenantId -ServicePrincipal)

if($isAzConnected){
    
    $VMCounts = $VirtualMachineNameArray.Count
    
    foreach($VirtualMachineNameItem in $VirtualMachineNameArray){

        Write-Host "Deallocating $VirtualMachine"

        Start-Job -ScriptBlock { 

                $isAzConnected = [bool](Connect-AzAccount -Credential $args[1] -TenantId $args[2] -ServicePrincipal)

                $ResourceGroupName = (Get-AzResource -Name $args[0] -ResourceType "Microsoft.Compute/virtualMachines").ResourceGroupName

                Stop-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $args[0] -Force

                Write-Host "Stopped: "$args[0]  

            } -ArgumentList $VirtualMachineNameItem, $AzCredential, $TenantId

            Start-Sleep -Seconds 1

        $progress = $progress + 1

        Write-Host "$progress out of $VMCounts"
    }

    Get-Job | Wait-Job | Receive-Job

    Get-Job | Remove-Job
}
else{
    throw("Authentication Failed")
}