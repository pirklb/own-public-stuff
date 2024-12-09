$Version='21.311.1'
# Version
#   21.311.1 ... Initialversion
$start='2021-03-10 18:00'

$r=[regex]::new('Account Name:\s+\[a-zA-Z0-9][^\r\n]+') # Logons, wo ein Accountname angegeben ist finden (Regex fuer Message)
$e=Get-EventLog -LogName Security -After $start -InstanceId 4624
$e4=$e | select-Object *,@{n='LogonType';e={$_.replacementstrings[8]}},@{n='Domain';e={$_.replacementstrings[6]}},@{n='Accountname';e={$_.replacementstrings[5]}}
$e4 | select-Object timegenerated,logontype,domain,accountname
