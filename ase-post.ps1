$Version = '21.1027.1'
    
if (!Test-Path -Path 'C:\Logs\Transcript') {
    New-Item -Path 'C:\Logs' -Name 'Transcript' -ItemType Directory
}
Start-Transcript -Path "c:\Logs\Transcript\ase-POST-$(Get-Date -Format yyyyMMdd_HHmmss).txt" | Out-Null
# $Body = Get-Content -Path "C:\temp\Remove-VirtualServer.json" -Raw
# Pass web request body to variable $Json
$Json = $Body
# Convert JSON to PowerShell Object for further processing in PowerShell
$Object = ConvertFrom-Json $Json
$Debug = $Object | Select-Object -ExpandProperty Debug -ErrorAction SilentlyContinue
if ($Debug -match "$true|enabled|1") { $Debug = $true } else { $Debug = $false }

if ($null -eq $Object.Username) {
    New-PSUApiResponse -StatusCode 500 -Body 'ERROR: username must be set'
    return
}
else {
    $username = $Object.username
}
if ($null -eq $Object.computer) {
    New-PSUApiResponse -StatusCode 500 -Body 'ERROR: computer must be set'
    return
}
else {
    $computer = $Object.computer
}
if ($null -ne $Object.ip) {
    $ip = $Object.ip
}
else {
    $ip = ''
}

Write-Host "Username:'$username';Computer:'$computer';ip:'$ip';Zeitpunkt:'$(get-date -format 'yyyy.MM.dd HH:mm:ss')"
