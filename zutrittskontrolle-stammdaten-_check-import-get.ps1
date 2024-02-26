
$Version='21.830.1'
# Version
#    21.813.1 ... Initialversion
#    21.818.1 ... Modules = @() statt @(''), weil zweiteres nicht mehr funktioniert
#    21.826.1 ... Funktionalitaet nachgebaut (ist irgendwie verloren gegangen und war auch noch nicht im bitucket eingecheckt)
#    21.827.1 ... info fuer Checkoutput mitschicken
#    21.827.2 ... info fuer Checkoutput gekuerzt, da WatchIT die fehlerhaften Details an den Checkoutput anhaengt - und damit an der Statistik kein Interesse besteht
#    21.830.1 ... Zeitformat fuer Name Logfilesicherung auf 24 Stunden umstellen

if (!(Test-Path -Path 'C:\Logs\Transcript')) {
    New-Item -Path 'C:\Logs' -Name 'Transcript' -ItemType Directory
}
Start-Transcript -Path "c:\logs\Transcript\zutrittskontrolle-stammdaten-_check-import-GET-$(Get-Date -Format yyyyMMdd_HHmmss).txt" | Out-Null

# Erforderliches PowerShell Universal Module importieren
try { Import-Module -Name Universal } catch { exit }

# benoetigte Module importieren – im Array $Modules angeben (zB ActiveDirectory)
$Modules = @()
foreach ($Module in $Modules) {
    try { Import-Module -Name "$Module" }
    catch {
        New-PSUApiResponse -StatusCode 500 -Body "ERROR: Module '$Module' NOT imported"
        exit
    }        
}

$logpfad='\\wipzut01\geco\geconet\log'
$logfile='stammimp.log'

if (Test-Path -Path ($logpfad + '\' + $logfile)) {
  Write-Host "Logfile '$logpfad\$logfile' gefunden"
  $l=Get-Content -Path ($logpfad + '\' + $logfile)
  $overallStatus='OK'
  $cntGelesen=0
  $cntVerarbeitet=0
  $cntDurchlaeufe=0
  $details=$l | Foreach-Object { 
    $akt=$_
    if ($akt -match '([\d\.\s\:\,]+) {2}(\d+).+\sAPI-\d+:.*->\s(\d+)/(\d+)$' ) {
      Write-Host ("Zeile enthaelt Information ueber Datensaetze: $akt")
      $cntDurchlaeufe++
      if ($matches[3] -ne $matches[4]) {
        $status='CRITICAL'
        $overallStatus='CRITICAL'
        Write-Host ("  nicht alle Datensaetze konnten verarbeitet werden")
      } else {
        $status='OK'
      }
      $cntGelesen += $matches[3]
      $cntVerarbeitet += $matches[4]
      [PSCustomObject]@{
        Status=$status
        pid=$matches[2]
        verarbeitet=$matches[4]
        gelesen=$matches[3]
      }
    }
  }

  $newName='stammimp-' + (get-Date -format 'yyyy-MM-dd--HH-mm') + '.log'
  if (Test-Path -Path ($logpfad + "\$newName")) {
    Remove-Item -Path ($logpfad + "\$newName") -Force
  }
  try {
    Get-Item -Path ($logpfad+"\$logfile") | Rename-Item -NewName $newName
    Write-Host ("Umbenennen des Logfiles auf '$newName' erfolgreich")
    $renameLogStatus="OK ($newName)"
  } catch {
    Write-Host ("Umbenennen des Logfiles auf '$newName' NICHT erfolgreich")
    $renameLogStatus="CRITICAL ($newName)"
  }
  $erg=[PSCustomObject]@{
    status=$overallStatus
    info="$cntDurchlaeufe geprueft ($newName)"
    details=$details
    renameLogStatus=$renameLogStatus
  }
  
} else {
  # kein Logfile vorhanden
  Write-Host ("KEIN Logfile '$logpfad\$logfile' gefunden")
  $erg=[PSCustomObject]@{
    status='NOFILE'
    info="kein Logfile gefunden"
    details=@()
    renameLogStatus="OK (kein Logfile gefunden)"
  }
}
$ergJson=$erg | Convertto-Json -Compress
New-PSUApiResponse -StatusCode 200 -Body ($ergJson) -Headers @{ScriptVersion=$Version}
Stop-Transcript | Out-Null
