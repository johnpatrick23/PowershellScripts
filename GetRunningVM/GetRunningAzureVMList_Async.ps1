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
    [string] 
    $ResourceGroupFilter

)

$AzSecureApplicationKey = $AppKey | ConvertTo-SecureString -AsPlainText -Force

$AzCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ClientId, $AzSecureApplicationKey

[bool]$isAzConnected = [bool](Connect-AzAccount -Credential $AzCredential -TenantId $TenantId -ServicePrincipal)

if($isAzConnected){
    $virtualMachines = Get-AzVM -Status | Where-Object {
        $_.ResourceGroupName -like "*$ResourceGroupFilter*" -and `
        $_.PowerState -notlike '*deallocated*' -and `
        $_.ProvisioningState -like 'Succeeded'
    }
    $virtualMachines
    $virtualMachines.Count
}
else{
    throw("Authentication Failed")
}