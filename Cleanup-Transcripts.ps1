# Cleanup-Transcripts
$Version='21.414.1'
# Version
#   21.414.1 ... erste Version
if (!(Test-Path -Path 'c:\logs\Transcript\jobs')) {
    New-Item -Path 'c:\logs\Transcript' -Name 'jobs' -ItemType Directory
} 
Start-Transcript -Path "c:\logs\Transcript\jobs\Cleanup-Transcripts-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt" | Out-Null
$maxAgeDays=30
$Paths=@('C:\Logs\Transcript')
foreach ($path in $Paths) {
    $files=Get-ChildItem -Path $path -Recurse
    Write-Host "$($files.count) in $path gefunden"
    $old=$files | Where-Object { $_.LastWriteTime.AddDays($maxAgeDays) -lt (get-Date)}
    Write-Host "$($old.count) aelter als $maxAgeDays Tage alt - diese daher loeschen"
    $old | Remove-Item -Force
}

Stop-Transcript | Out-Null