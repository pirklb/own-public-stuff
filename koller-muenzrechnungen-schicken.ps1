param(
    [string][Alias('d','dir','Path')]$directory='',
    [Parameter(Helpmessage='Mit diesem Switch werden die Mails ueber das lokale Outlook verschickt - dieses muss laufen')][switch]$outlook,
    [Parameter(Helpmessage='Mit diesem Switch werden die Dateien nach dem Verschicken nicht geloescht - interessant, wenn nicht ueber Outlook verschickt wird')][switch]$dontRemove,
    [Parameter(Helpmessage='Mit diesem Switch werden die Dateien nicht geschickt - interessant, fuer erste Tests. Verhindert auch das Loeschen der Dateien - unabhaengig vom Switch dontRemove')][switch]$dontSend,
    [Parameter(Helpmessage='Mit diesem Switch werden die Mails an die Testadressen geschickt, ohne an die PROD-Adressen)')][switch]$Test
)
$Version='21.611.2'
# Version
#   21.525.1 ... Initialversion
#   21.525.2 ... Versand auch ueber Outlook moeglich
#   21.609.1 ... korrekte Mailadressen eingefuegt - und Switch Test
#   21.609.2 ... Switch dontSend eingebaut
#   21.609.3 ... Rechtschreibfehler Kommentar Zeile 23 korrigiert
#   21.609.4 ... Protokoll erweitert (manchmal wird ein richtiger Mandant als unbekannt ausgewiesen - korrigiert)
#   21.609.5 ... Ergebnis vom .send() bei Outlook nicht auf STDOUT ausgeben
#   21.609.6 ... Ergebnis vom .Attachments.Add() ebenfalls nicht auf STDOUT ausgeben
#   21.611.1 ... Mandantenkürzen für PROD erweitert
#   21.611.2 ... Transcript eingebaut

$Transcript=$env:Temp+'\Muenzrechnungen-schicken.txt'
if (Test-Path -Path $Transcript) {
    Get-ChildItem -Path $Transcript | Remove-Item -Force
}
Start-Transcript -Path $Transcript
$mailPROD=@{
    CTX='rechnung@containex.com'
    CXW='rechnung@containex.com'
    LKW='rechnung@lkw-walter.com'
    WGS='rechnung@walter-group.com'
    WLL='rechnung@walter-lager-betriebe.com'
    WLB='rechnung@walter-lager-betriebe.com'
    WLG='rechnung@walter-leasing.com'
}
# zum Testen ... (ACHTUNG: Widerspruch bei CTX/CXW)
$mailTEST=@{
    CTX='koller@walter-group.com'
    LKW='pirklbauer@walter-group.com'
    WLB='schmid@walter-group.com'
    WGS='koller@walter-group.com'
}
if ($Test) {
    $mail=$mailTEST
} else {
    $mail=$mailPROD
}
#region Verzeichnis auswaehlen
try {
    Add-Type -AssemblyName System.Windows.Forms
    if (!($directory -and (Test-Path $directory))) {
        $directory=$env:Temp
    }
    $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
        SelectedPath = $directory
        ShowNewFolderButton = $false
    }
    [void]$FolderBrowser.ShowDialog()
    $directory=$FolderBrowser.SelectedPath
} catch {
    Write-Host ("Verzeichnisauswahldialog kann nicht angezeigt werden, daher bitte das Verzeichnis hier eingeben")
    do {
        $dir=Read-Host -Prompt ("Verzeichnis (ENTER fuer '$directory')")
        if (!$dir) { $dir=$directory }
    } until ($dir -and (Test-Path ($dir)))
    $directory=$dir
}
# endregion
#region ueber alle PDF-Dateien iterieren
$dateien=get-ChildItem -Path $directory
foreach ($datei in $dateien) {
    $Dateiname=$datei.Name
    Write-Host "Datei '$Dateiname' verarbeiten"
    if ($Dateiname -imatch '^\w{3}\sre[^.]*\.pdf$') {
        $mandant=$Dateiname.substring(0,3)
        $mailTo=$mail.$mandant
        if ($mailTo) {
            Write-Host "   Datei '$Dateiname' fuer Mandant '$mandant' an '$mailTo' senden"
            #region Mailsenden ...
            $gesendet=$false
            if ($outlook) {
                # ... ueber Outlook
                try {
                    $o = New-Object -ComObject Outlook.Application
                    $mailItem = $o.CreateItem(0)
                    $mailItem.subject = "Muenzrechnung"
                    $mailItem.To = $mailTo
                    $mailItem.Attachments.Add($Datei.Fullname) | Out-Null
                    if (!$dontSend) {
                        $dummy=$mailItem.send()
                    }
                    $gesendet=$true
                } catch {
                    Write-Host ("   Outlook Sendmail hat nicht funktioniert: $($Error[0])")
                }
            } else {
                # ... ueber Send-MailMessage
                try {
                    if (!$dontSend) {
                        send-mailmessage -From 'pirklbauer@walter-group.com' -to $mailto `
                            -SmtpServer relay-intern.lkw-walter.com -Attachments ($datei.Fullname) `
                            -Subject "Muenzrechnung, Mandant '$mandant'" -ErrorAction Stop
                    }
                    $gesendet=$true
                } catch {
                    Write-Host ("   Send-Mailmessage hat nicht funktioniert: $($Error[0])")
                }
            }
            #endregion
            #region Datei loeschen
            if ($gesendet) {
                # Remove File
                Write-Host "   Datei '$Dateiname' loeschen"
                if (!($dontRemove -or $dontSend)) {
                    Remove-Item -Path ($datei.Fullname) -Force
                }
            }
            #endregion
        } else {
            Write-Host "   Unbekannter Mandant: '$mandant' (mailto:'$mailTo', mail:'$($mail | Convertto-json -compress)')"
        }
    } else {
        Write-Host "Dateiname '$Dateiname' matcht nicht auf '^\w{3}\sre[^.]*\.pdf$'"
    }
}
#endregion
Stop-Transcript