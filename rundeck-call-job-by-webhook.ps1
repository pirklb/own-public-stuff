# Webhook-URL
$whurl='https://selfservice-rundeck.prod.lkw-walter.com/api/41/webhook/WWSI66cjfE7PQhC2joolUf6PK1hWyRfB#infra-test-mit-delay'
# Authorization-Token for the Webhook
$t='o19BtZq62AsahwtwRuYOZuCv9pHNwyB1'
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.add('Content-Type','application/json')
$headers.add('Authorization',$t)

# Body for the request
# the job has one option, also called vmname
$body='{"vmname":"noauth.webhook","waitSeconds":"200"}'

# call the Webhook
$result=Invoke-RestMethod -Uri $whurl -Method POST -Body $body -Headers $headers

# long running job - how to check the result???

$ut='8vhq0v69TukddU2Az4PjsmDrVT8VReAh'
$authHeader = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$authHeader.add('Content-Type','application/json')
$authHeader.add('X-Rundeck-Auth-Token',$ut)

$exeUrl="https://selfservice-rundeck.prod.lkw-walter.com/api/41/execution/$($result.executionId)/state"
$timeout=300
$pauseSeconds=$timeout/30
$start=get-date

do {
    $x=(Invoke-RestMethod -Method get -Uri $exeUrl -Headers $backup)
    $cState=$x.executionState
    Write-Host ("current state: " + $cState)
    if ($cState -ieq 'RUNNING') {
        Start-Sleep -Seconds $pauseSeconds
    }
    $duration=(New-Timespan -Start $start -End (get-date)).TotalSeconds
} until (($cState -ine 'RUNNING') -or ($duration -gt $timeout))

