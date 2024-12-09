param(
  $CSV='T:\A1 Versand Roboter\Versand_20221221.csv'
)
$Version='23.104.1'
# 22.1220.1 - Initialversion
# 22.1221.1 - mehr Logging
# 23.104.1 - noch mehr Logging
# die Exchange-DLL liegt am WIPPER04 auf C:\Temp
function Connect-Exchange {
    param(
        $DLL = '$PSScriptRoot\Microsoft.Exchange.WebServices.dll',
	$username = 'svc_a1bescheinigunguser_p@walter-group.com', # Userprincipalname
        $pw = 'BP-(et34s-?tP9^#35=WWM^F@',
        [switch]$connectDrive
    )
    [pscredential]$Credential = New-Object System.Management.Automation.PSCredential ($username,(ConvertTo-SecureString $pw -AsPlainText -Force))
    if ($connectDrive) {
        net use t: \\wipfil13\Gruppen /user:$username "$pw"
    }

    try {
        Import-Module $DLL
        $exchService = New-Object -TypeName Microsoft.Exchange.WebServices.Data.ExchangeService
        $exchService.Credentials = New-Object -TypeName Microsoft.Exchange.WebServices.Data.WebCredentials -ArgumentList $Credential.UserName, $Credential.GetNetworkCredential().Password
        #$exchService.AutodiscoverUrl($Credential.UserName, {$true})
        #$exchService.Url = 'https://mxw01s.lkw-walter.com/EWS/Exchange.asmx'
        $exchService.Url = 'https://outlook.exchange.prod.lkw-walter.com/EWS/Exchange.asmx'
        $exchService
    } catch {
        $false
    }
}

function Send-EWSMail {
    param(
        $exchService,
        [Alias('Betreff','s')][string]$subject,
        [string]$body,
        [string[]]$recipients,
        $Sensitivity,
        [switch]$bodyTextOnly,
        [Alias('Attachment','f','file')][string]$Attachmentfilename
    )
    
    #$Sensitivity='Personal'
    $eMail = New-Object -TypeName Microsoft.Exchange.WebServices.Data.EmailMessage -ArgumentList $exchService
    $eMail.Subject=$Subject
    $eMail.Body = New-Object Microsoft.Exchange.WebServices.Data.MessageBody  
    $eMail.Body=$body
    foreach ($r in $recipients) {
        $eMail.ToRecipients.Add($r)
    }
    $eMail.Sensitivity = $Sensitivity
    if ($AttachmentFilename) {
        if (Test-Path $AttachmentFilename) {
           $eMail.Attachments.AddFileAttachment($AttachmentFilename)
        } else {
           ((get-date -format 'yyyy.MM.dd HH:mm:ss ') + "Attachment '$AttachmentFilename' NICHT gefunden (recipient='$($recipients -join ',')').") | Out-File $logFile -Append
           $eMail.Body = "$body `n`nAttachment ($AttachmentFilename) wurde nicht gefunden, daher nicht angefuegt"
        }
    }
    if ($bodyTextOnly) {
        $eMail.Body.BodyType = [Microsoft.Exchange.WebServices.Data.BodyType]::Text
    } else {
        $eMail.Body.BodyType = [Microsoft.Exchange.WebServices.Data.BodyType]::HTML
    }
    try {
        $eMail.Send()
        Write-Host "Mail sent: OK ($subject)"
        $fehler=$false
        "Mail an '$($recipients -join ',')' erfolgreich versandt (Attachment: '$AttachmentFilename')" | Out-File $logFile -Append
    } catch {
        Write-Host "Mail sent: ERROR ($subject)"
        $fehler = $true
        ((get-date -format 'yyyy.MM.dd HH:mm:ss ') + "ERROR: Mail an '$($recipients -join ',')' NICHT versandt (Attachment: '$AttachmentFilename')") | Out-File $logFile -Append
    }
    if (!$fehler) {
        $dest=(($AttachmentFilename | Split-Path -Parent) + '\sent')
        if (!(Test-Path $dest)) {
            New-Item $dest -ItemType Directory
        }
        Write-Host "Verschiebe '$AttachmentFilename' nach '$dest'"
        Move-Item -Path $AttachmentFilename -Destination $dest
    }
}
Start-Transcript -Path ('c:\Temp\Logs-A1Bescheinigung-Versand-Transcript-' + (get-date -format 'yyyy-MM-dd--HH-mm-ss') + '.txt')
Add-Type -AssemblyName System.Web

$logfile='T:\A1 Versand Roboter\Logfile.txt'
if ($PSScriptRoot) {
  # wenn als Skript ausgefuehrt, DLL im Skriptverzeichnis verwenden
  $mod="$PSScriptRoot\Microsoft.Exchange.WebServices.dll"
} else {
  # interaktiv -> hier den Pfad hartcodiert eintragen
  $mod='C:\Script\Austrittsinformation\Microsoft.Exchange.WebServices.dll'
}
$body=@'
Liebe Kollegin,
Lieber Kollege,

gegen behördliche Aufforderung ist bei Dienstreisen eine Entsendebescheinigung (A1) vorzuweisen.

Beiliegend finden Sie die Bescheinigung mit Ihren persönlichen Daten.

Es ist ausreichend, wenn Sie das Dokument elektronisch vorweisen können – bitte speichern Sie es auf Ihrem Mobiltelefon ab.

Das Dokument wird von der Österreichischen Gesundheitskasse (ÖGK)  nur in deutscher Sprache erstellt.

Liebe Grüße,
Irmgard Kerschbaumer
'@

if (Test-Path $mod) {
  Write-Host "EWS-Modul: '$mod'"
  $exchService=Connect-Exchange -DLL $mod -connectDrive

  if (Test-Path $csv) {
    $c=Import-Csv -Path $csv -Delimiter ';' | Where-Object { $_.Pfad }
    Write-Host ("Steuerdatei: '$csv' - Anzahl: $($csv.count)")
    foreach ($zeile in $c) {
       Write-Host "Verarbeite $($zeile.Mail) - Attachment '$($zeile.pfad)'"
      Send-EWSMail -exchService $exchService -subject 'Dienstreise' -body $body -recipients ($zeile.Mail) -Sensitivity Private -bodyTextOnly -Attachmentfilename ($zeile.pfad)
    }
  } else {
    ((get-date -format 'yyyy.MM.dd HH:mm:ss ') + "Steuerdatei '$csv' nicht gefunden.") | Out-File $logFile -Append
  }
} else { Write-Host "EWS-Modul ('$mod') nicht gefunden" }
Stop-Transcript