$Version='21.310.3'
# Version
#   21.310.1 ... Initialversion (bis auf den Clusternamen 1:1 von https://communities.vmware.com/t5/VMware-PowerCLI-Discussions/DRS-VM-Overrides/td-p/2259888 kopiert)
#   21.310.2 ... nur VMs mit wirklichem Override, dafuer ueber alle Cluster iterieren
#   21.310.3 ... weitere Eigenschaften mitaufgenommen - es fehlt noch vSphere HA - VMs mit der nächsten Priorität unter folgenden Bedingungen starten
Connect-VIServer -Server vmm01s.lkw-walter.com

# DasVMConfig
# $cluster.ExtensionData.ConfigurationEx.DasVmConfig | where { $_.key -eq $v.ExtensionData.MoRef }
# DrsVMConfig
# $cluster.ExtensionData.ConfigurationEx.DrsVmConfig | where { $_.key -eq $v.ExtensionData.MoRef }
# VMReadiness
# ($cluster.ExtensionData.ConfigurationEx.VmOrchestration | where { $_.VM -eq $v.ExtensionData.MoRef }).VMReadiness

$VMOverrides=Get-Cluster -PipelineVariable cluster |
Get-VM -PipelineVariable vm | where-object { $_.DrsAutomationLevel -ne 'AsSpecifiedByCluster'} | # nur VMs mit wirklichem Override
Select-Object @{N='Cluster';E={$cluster.Name}},
    @{N='VM';E={$_.Name}},
    @{N='DRS Automation Level';E={$_.DrsAutomationLevel}},
    @{N='VM Restart Priority';E={$_.HARestartPriority}},
    @{N='Additional Delay';E={
        $script:orch = $cluster.ExtensionData.ConfigurationEx.VmOrchestration |
            Where-Object{$_.Vm -eq $vm.ExtensionData.MoRef} |
            Select-Object -ExpandProperty VmReadiness
        if(-not $script:orch){
            $script:orch = $cluster.ExtensionData.ConfigurationEx.Orchestration.DefaultVmReadiness
        }
        $script:orch.PostReadyDelay}},
    @{N='After Timeout';E={
        $script:ha = $cluster.ExtensionData.ConfigurationEx.DasVmConfig |
            Where-Object{$_.Key -eq $vm.ExtensionData.MoRef} |
            Select-Object -ExpandProperty DasSettings
         if(-not $script:ha){
            $script:ha = $cluster.ExtensionData.ConfigurationEx.DasConfig.DefaultVmSettings
        }
        $script:ha.RestartPriorityTimeout}},
    @{N='Host Isolation';E={$_.HAIsolationResponse}},
    @{N='Permanent Device Loss';E={$script:ha.VmComponentProtectionSettings.VmStorageProtectionForPDL}},
    @{N='All Path Down Error Response';E={$script:ha.VmComponentProtectionSettings.VMStorageProtectionForAPD}},
    @{N='APD - VM Reaction Delay';E={$script:ha.VmComponentProtectionSettings.VMTerminateDelayForAPDSec}},
    @{N='APD - VM Reaction On APD Cleared';E={$script:ha.VmComponentProtectionSettings.VMReactionOnAPDCleared}}




