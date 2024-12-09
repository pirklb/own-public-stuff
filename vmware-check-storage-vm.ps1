
$Version = '21.309.3'
# Version
#   21.224.1 ... Initialversion
#   21.225.1 ... komplett neu geschrieben und vorbereitet fuer WatchIT (Ergebnis in JSON)
#   21.303.1 ... ContentType 'application/json' ergaenzt
#   21.305.1 ... Bedingung im if falsch geschachtelt
#   21.305.2 ... bei leerem Ergebnis [] zurückliefern
#   21.309.1 ... Clustername ebenfalls retour liefern
#   21.309.2 ... Modulpfad fuer Powershell Universal korrigiert
#   21.309.3 ... Syntaxerror Zeile 33 korrigiert
$excludedDatastores = @('vSAN-Intern-Synergy','HPWW1_ESX_NoDSCluster_99','HPWW1_ESX_Citrix_01')

$Module = 'C:\inetpub\wwwroot\GMSAPowershellUniversal\Universal.Cmdlets.dll'
try { Import-Module "$Module" }
catch {
    "ERROR: Module '$Module' NOT imported"
    exit
}
$Modules = @('VMware.VimAutomation.Core')
foreach ($Module in $Modules) {
    try { Import-Module -Name "$Module" }
    catch {
        New-PSUApiResponse -StatusCode 424 -Body "ERROR: Module '$Module' NOT imported"
        exit
    }        
}

Connect-VIServer vmm01s.lkw-walter.com | Out-Null
$vm = get-VM
$ds = Get-Datastore | Select-Object Id,Name
$dsHash = $ds | Foreach-Object {
    @{$_.Id=$_ | Select-Object -Property * -ExcludeProperty Id }
}
$dsVMHosts = get-VMHost | Foreach-Object {
  @{$_.Name = ($_ | Get-Cluster).Name}
}
$Fehleranzahl=0
$falscheVMs = $vm | ForEach-Object {
    $aktVM = $_
    $aktCluster = $dsVMHosts."$($aktVM.VMHost.name)"
    $aktVMHost = $aktVM.VMHost.name -ireplace '.lkw-walter.com',''
    $aktDS=$aktVM.DataStoreIdList
    if ($aktDS.Count -ne 1) {
        [PSCustomObject]@{
            Name      = $aktVM.name
            Cluster   = $aktCluster
            Host      = $aktVMHost
            Status    = 'WARNING'
            Datastore = 'multiple datastores (' + $aktDS.count + ')'
        }
    } else {
        $aktDSName=$dsHash.$aktDS.Name
        if ($aktDSname -inotin $excludedDatastores) {
            if ( ( ($aktDSname -like 'HPWW*') -and ((($aktVMHost.substring($aktVMHost.length-1,1)) -in @(0,2,4,6,8))) ) -or 
                 ( ($aktDSname -like 'HPWC*') -and ((($aktVMHost.substring($aktVMHost.length-1,1)) -in @(1,3,5,7,9))) ) ) {
                    $fehlerAnzahl++
                    [PSCustomObject]@{
                        Name      = $aktVM.name
	                Cluster   = $aktCluster
                        Host      = $aktVMHost
                        Status    = 'CRITICAL'
                        Datastore = $aktDSName
                    }
                                
            }
        }
    }
}
#Write-Debug ("$fehlerAnzahl falsch laufende VMs gefunden")
if ($falscheVMs) {
    $ergebnis=$falscheVMs | Sort-Object -Property Status,Name | ConvertTo-Json -Compress
} else {
    $ergebnis='[]'
}
New-PSUApiResponse -Body $ergebnis -StatusCode 200 -ContentType 'application/json'
