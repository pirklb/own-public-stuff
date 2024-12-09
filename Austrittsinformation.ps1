param(
    $Standort='*'
)
$Version='22.208.1'
# 20.1105.2 - Orgeinheitencode (bei Beschaeftigungsende) wird in der Infomail ebenfalls angegeben
# 20.1119.1 - Import-CSV -Encoding UTF8
# 20.1119.2 - Anpassungen fuer Lauf auf WIPPER04 (+ Korrektes schicken von Umlauten im Betreff, sprich Mitarbeiternamen)
# 20.1120.1 - Logging eingebaut
# 20.1125.1 - DV-Ende soll in der Info nicht enthalten sein
# 20.1201.1 - Anrede als zusaetzliches Feld und Umformulierung Mailtext
# 20.1202.1 - Fehler beim Mailtext korrigiert (falsche Anfuehrungszeichen)
# 20.1204.1 - Umformulierung Mailtext (Personalnummer)
# 20.1209.1 - Umbau, so dass alle Datenfiles auf einmal eingelesen werden und nach Personalnummer unique sortiert werden (damit nicht mehrfach die gleiche Personalnummer benachrichtigt wird)
# 20.1209.2 - Fehler bei Auswerten bereits verschickter PersNrs korrigiert
# 20.1222.1 - Protokollieren, welche Personalnummern vergessen wurden
# 21.209.1 - Protokollieren, welche Personalnummern vergessen wurde noch erweitert; beim Vergessencheck Zeitpunkt auf timestamp konvertiert
# 21.209.2 - Vergessen umstellen (Personalnummern, die in keinem Datenfile mehr vorkommen, vergessen)
# 21.209.3 - Syntaxfehler Zeile 116 (fehlende Klammer)
# 21.209.4 - Beim CheckVergessen haben sich noch zwei Tippfehler eingeschlichen gehabt
# 21.211.1 - Protokollieren Vergessen erweitert
# 21.212.1 - wenn PersNr dazugekommen sind oder vergessen wurden, Protokoll schreiben (davor wurde es nur geschrieben, wenn neue Personalnummern dazugekommen sind)
# 21.830.1 - Zeitpunkt, wann schon verschickt wurde, mitprotokollieren
# 21.830.2 - Info, zu vergessende Personalnummern ueberarbeitet
# 22.204.1 - Moeglichkeit auf einen bestimmten Standort zu filtern
# 22.204.2 - gewaehlter Standort wird protokolliert
# 22.207.1 - Umstellung auf Exchange Web Service (wegen persoenlich schicken) - im Skriptverzeichnis wird die "Microsoft.Exchange.WebServices" benoetigt
# 22.208.1 - Connect-Exchange und Send-EWSMail korrigiert
function Connect-Exchange {
    param(
        $DLL = "$PSScriptRoot\Microsoft.Exchange.WebServices.dll",
	$username = 'austritte-sender@walter-group.com',
        $pw = 'sk:NrmN~vi~j@Usht/h6ty{6Z^}FXwz!G[XEX[Nz\#-w+Y:e\F^fXxh,c-]L2Y&MS!2TndfKe\z~FPN~p:YUJ[knCJ-f7j&@7{w<6_d6#Ga_C+~,(#PhLn\9J|84,9N' 
    )
    [pscredential]$Credential = New-Object System.Management.Automation.PSCredential ($username,(ConvertTo-SecureString $pw -AsPlainText -Force))
    try {
        if (Test-Path $DLL) {
            Write-Host ("DLL: '$DLL' wird importiert ...")
            Import-Module $DLL
            $exchService = New-Object -TypeName Microsoft.Exchange.WebServices.Data.ExchangeService
            $exchService.Credentials = New-Object -TypeName Microsoft.Exchange.WebServices.Data.WebCredentials -ArgumentList $Credential.UserName, $Credential.GetNetworkCredential().Password
            #$exchService.AutodiscoverUrl($Credential.UserName, {$true})
            #$exchService.Url = 'https://mxw01s.lkw-walter.com/EWS/Exchange.asmx'
            $exchService.Url = 'https://outlook.exchange.prod.lkw-walter.com/EWS/Exchange.asmx'
            $exchService
        } else {
            Write-Host ("DLL: '$DLL' nicht gefunden")
            $false
        }
    } catch {
        Write-Host "bei Connect-Exchange ist ein Fehler aufgetreten"
        $false
    }
}
function Send-EWSMail {
    param(
        $exchService,
        [Alias('Betreff','s')][string]$subject,
        [string]$bodyHTML,
        [string[]]$recipients
    )
    
    $Sensitivity='Personal'
    $eMail = New-Object -TypeName Microsoft.Exchange.WebServices.Data.EmailMessage -ArgumentList $exchService
    $eMail.Subject=$Subject
    $eMail.Body=$bodyHTML
    foreach ($r in $recipients) {
        $eMail.ToRecipients.Add($r)
    }
    $eMail.Sensitivity = $Sensitivity
    try {
        $eMail.Send()
        Write-Host "Mail sent: OK ($subject)"
        "Mail betreffend '$subject' erfolgreich versandt" | Out-File $logFile -Append
    } catch {
        Write-Host "Mail sent: ERROR ($subject)"
        $fehler = $true
        "Fehler beim Versenden der Mail betreffend '$subject'" | Out-File $logFile -Append
    }
}
Add-Type -AssemblyName System.Web

$logAge=30
$jetzt=Get-Date -Format 'yyyyMMdd-HHmmss' 
$logfileBasename="C:\Temp\Logs\Austrittsinformation"
$logfile="$logfileBasename-$jetzt.txt"
$oldLogs=Get-ChildItem ($logfileBasename+'*.txt') | Where-Object { $_.lastwritetime -lt ((get-date).AddDays(-$logAge)) }
$oldLogs | ForEach-Object { $_.Fullname | Remove-Item -Force }
"$jetzt - " + $oldLogs.Count + " alte Logfiles (aelter $logAge Tage) geloescht" | Out-File $logFile
"Standortfilter='$Standort'" | Out-File $logFile -Append

$pfad='C:\CSV_BESCHENDE'
$recipients=@('pers-austritte-info@walter-group.com')
#$recipients=@('pirklbauer@walter-group.com')
$ProtokollCSV='C:\Script\Austrittsinformation\Austritte-Verschickt-Protokoll.csv'
$ProtokollVergessenCSV='C:\Script\Austrittsinformation\Austritte-Verschickt-Protokoll-Vergessen.csv'
$ersteMail=$true
if (Test-Path -Path $ProtokollCSV) {
    $bereitsVerschickt=Import-Csv $ProtokollCSV -Delimiter ';'
} else {
    $bereitsVerschickt=@()
}
$bereitsVerschicktPNR=($bereitsVerschickt | Select-Object PersNr | Sort-Object -Property PersNr).PersNr -join ','
"bereits verschickte Austrittsinformationen ($($bereitsVerschickt.Count)): $bereitsVerschicktPNR" | Out-File $logFile -Append
$Austritte=foreach ($InputCSV in (get-Childitem -Path "$pfad\Beschaeftigungsende*.csv")) {
    "Lade CSV: $($InputCSV.Fullname)"  | Out-File $logFile -Append
    Import-CSV -Path ($InputCSV.Fullname) -Delimiter ';' -encoding UTF8
}
$Austritte=$Austritte | sort-object -Property PNR -Unique
$checkPNRJson=($Austritte | Select-object PNR).PNR -join ','
"Checke Personalnummern: $checkPNRJson" | Out-File $logFile -Append

$bereitsVerschicktNeu=$Austritte | Foreach-Object {
    # Umsetzen CSV-Spalten auf Variablen, damit sich bei Aenderung der Spaltennamen im CSV im Skript sonst nix aendert
    $akt=$_
    $Anrede=$akt.ANREDEK
    if ($Anrede -ieq 'Frau') { $ErSie='Sie' } else { $ErSie='Er' }
    $nachname=$akt.NAME
    $vorname=$akt.VNAME
    $PersNr=$akt.PNR
    $Mandant=$akt.MANDANT
    $Status=$akt.STATUS
    $Abteilung=$akt.ABTLG
    $OrgBeschEnde=$akt.Abteilung_zu_BESCH_Ende_Code
    $OrgBeschEndeText=$akt.Abteilung_zu_BESCH_Ende
    $OrgDVEnde=$akt.Abteilung_zu_DV_Ende_Code
    $OrgDVEndeText=$akt.Abteilung_zu_DV_Ende
    $Stammmandant=$akt.org_sman_bez
    $MAStandort=$akt.org_sman_ort
    $DV_Ab=$akt.DV_Ab
    $DV_Bis=$akt.DV_Bis
    $BeschEnde=$akt.BESCHENDE
    $TechnAustritt=$akt.TECHN_AUSTRITT
    "    Verarbeite '$vorname $nachname ($PersNr)'"  | Out-File $logFile -Append
    if (($BeschEnde | get-date) -lt (get-Date)) {
        # erfuellt die Benachrichtigungsanforderung (letzter Arbeitstag in der Vergangenheit)
        "        letzter Arbeitstag ($BeschEnde) in der Vergangenheit"  | Out-File $logFile -Append    
        if (!($PersNr -in ($bereitsVerschickt.PersNr))) {
            "        noch nicht in der Vergangenheit verschickt"  | Out-File $logFile -Append    
            if ($MAStandort -like $Standort) {
                $bodyHTML='<p style="font-size:10.0pt;font-family:Arial">' + `
                    [System.Web.HttpUtility]::HtmlEncode("$Anrede $vorname $nachname (Persnr $PersNr) ist am $BeschEnde ausgetreten.") + '<br><br>' + `
                    [System.Web.HttpUtility]::HtmlEncode("$ErSie war am Standort $MAStandort beim Mandant $Mandant in der Abteilung '$OrgBeschEndeText ($OrgBeschEnde)' tätig.") + '<br>' 
                "    Body: '$bodyHTML'"  | Out-File $logFile -Append
                try {
                    $subject="Mitarbeiteraustritt - $vorname $nachname ($PersNr)"
                    if ($ersteMail) {
                        $exchService=Connect-Exchange
                        $ersteMail=$false
                    }
                    if ($exchService) {
                        Send-EWSMail -exchService $exchService -Body $bodyHTML -Subject $subject -recipients $recipients
                    } else {
                        Send-Mailmessage -Body $bodyHTML -BodyAsHTML -from 'austritte@walter-group.com' -to $recipients -Subject $subject -SmtpServer relay-intern.lkw-walter.com -Encoding ([System.Text.Encoding]::UTF8)
                        "Achtung! Mailversand nur ueber Send-Mailmessage, daher kein 'persoenlich'" | Out-File $logFile -Append
                    }
                    "    Mail verschickt an '$recipients'" | Out-File $logFile -Append
                    [PSCustomObject]@{
                            PersNr = $PersNr;
                            Zeitpunkt = get-date
                    }
                } catch {
                        "    ! ! ! Fehler beim Verschicken der Infomail"  | Out-File $logFile -Append
                        $fehler=$true
                }
            } else {
                "        Mitarbeiterstandort ($MAStandort) matcht nicht mit Paramter Standort ($Standort)"  | Out-File $logFile -Append    
            }
        } else {
            $datum=(($bereitsVerschickt | Where-Object { $_.PersNr -eq $PersNr})[0]).Zeitpunkt -replace '\s.*',''
            "        bereits in der Vergangenheit ($datum) verschickt"  | Out-File $logFile -Append    
        }
    } else {
        "        letzter Arbeitstag ($BeschEnde) nicht in der Vergangenheit"  | Out-File $logFile -Append    
    }
}

#region vergessen von Personalnummern, die in keinem Daten-CSV mehr vorkommen
$bereitsVerschicktVergessen = $bereitsVerschickt | Foreach-Object {
    $aktZeile = $_
    $checkePNR=$aktZeile.PersNr
    if ($checkePNR -notin (($Austritte | Select-object PNR).PNR)) {
        "Personalnummer '$checkePNR' kommt in keinem Daten-CSV mehr vor, daher vergessen" | Out-File $logFile -Append
	$aktZeile
    }    
}

if ($bereitsVerschicktVergessen) {
    ("Folgende Personalnummern sollen vergessen werden: $(@($bereitsVerschicktVergessen).Count): " + (($bereitsVerschicktVergessen | Select-Object PersNr).PersNr -join ',')) | Out-File $logFile -Append
    $bereitsVerschickt =$bereitsVerschickt | Where-Object { ($_.PersNr -notin (($bereitsVerschicktVergessen | Select-Object PersNr).PersNr)) }
    $bereitsVerschicktPNR=($bereitsVerschickt | Select-Object PersNr | Sort-Object -Property PersNr).PersNr -join ','
    "Folgende Personalnummern bleiben im Protokoll erhalten: $(@($bereitsVerschickt).Count): $bereitsVerschicktPNR" | Out-File $logFile -Append
}

if ($bereitsVerschicktNeu) {
    "neu Verschickte Austrittsinformationen: $(@($bereitsVerschicktNeu).Count)" | Out-File $logFile -Append
    $bereitsVerschickt = (@($bereitsVerschickt) + $bereitsVerschicktNeu)
    "gesamt Verschickte Austrittsinformationen: $(@($bereitsVerschickt).Count)" | Out-File $logFile -Append
}

if ($bereitsVerschicktNeu -or $bereitsVerschicktVergessen) {
    $bereitsVerschicktPNR=($bereitsVerschickt | Select-Object PersNr | Sort-Object -Property PersNr).PersNr -join ','
    "bereits verschickte Austrittsinformationen ($($bereitsVerschickt.Count)): $bereitsVerschicktPNR" | Out-File $logFile -Append
    $bereitsVerschickt | Export-Csv -Path $ProtokollCSV -delimiter ';' -NoTypeInformation
} else {
    "keine Veraenderungen an betroffenen Personalnummern" | Out-File $logFile -Append
}

#endregion vergessen von Personalnummern, die in keinem Daten-CSV mehr vorkommen
# alte Datendateien loeschen
foreach ($InputCSV in (get-Childitem -Path "$pfad\Beschaeftigungsende*.csv")) {
    if ($InputCSV.LastWriteTime.AddDays(30) -lt (get-Date)) {
        "Loesche Datenfile '$($InputCSV.Fullname), aelter als 30 Tage" | Out-File $logFile -Append
        $inputcsv | Remove-Item -Force -Confirm:$false
    }
}
