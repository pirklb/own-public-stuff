#region Script Allgemeines
# Offener Punkt
# Arbeitsplatz soll auch b:Beschreibung lauten duerfen (statt namenlos), Beispiel: b:Raum 6333
param(
  [int][Alias('b','rb','build')]$requiredBuild=19042,
  [string][Alias('s','p','pfad')]$Share='\\lkw-walter.com\data\wnd\transfer\loginablauf\Inventur-Wochenende'
)

$Version = '21.316.4'
#Version
#  21.315.1 ... Initialversion Christoph
#  21.316.1 ... Buildnummer automatisch ermitteln und Fenster nur anzeigen, wenn Abweichung vorhanden
#  21.316.2 ... Share (fürs Ergebnis als Kommandozeilenparameter - mit Standardwert)
#  21.316.3 ... Fehler bei der Abfrage Arbeitsplatz behoben
#  21.316.4 ... statt namenlos Möglichkeit einer Beschreibung (indem mit b: begonnen wird)

##XAML for Window
#$XAMLFile = $pwd.Path + '\MainWindow.xaml'
$XAMLFile = (Split-Path ((Get-Variable MyInvocation).Value).MyCommand.Path) + '\MainWindow.xaml'

$XAMLContent = (Get-Content -Path $XAMLFile) -replace "^<Window.*", "<Window"

$xaml = @"
$XAMLContent
"@

$NamedElements = @(
	'Lbl_EstimatedWinVersion',
	'Lbl_InstalledWinVersion'
)

#region Code for Convert XAML to Window and Convert XAML to Window
function Convert-XAMLtoWindow {
	param
	(
		[Parameter(Mandatory)][string]$XAML,
    	[string[]]$NamedElement = $null,
    	[switch]$PassThru
	)

	Add-Type -AssemblyName PresentationFramework
  
	$reader = [XML.XMLReader]::Create([IO.StringReader]$XAML)
	$result = [Windows.Markup.XAMLReader]::Load($reader)
	foreach ($Name in $NamedElement) {
		#If ($MyDebug) { Write-Host "Current WPF Named Element = $($Name)" }
		$result | Add-Member NoteProperty -Name $Name -Value $result.FindName($Name) -Force
	}
  
	if ($PassThru) {
		$result
	}
	else {
		$null = $window.Dispatcher.InvokeAsync{
			$result = $window.ShowDialog()
			Set-Variable -Name result -Value $result -Scope 1
		}.Wait()
		$result
	}
}

function Show-WPFWindow {
	param
	(
		[Parameter(Mandatory)]
		[Windows.Window]
		$Window
	)
  
	$result = $null
	$null = $window.Dispatcher.InvokeAsync{
		$result = $window.ShowDialog()
		Set-Variable -Name result -Value $result -Scope 1
	}.Wait()
	$result
}

# Arbeitsplatzinformation abfragen
do {
  $Arbeitsplatz=read-host 'Arbeitsplatzbezeichnung(oder B:Beschreibung, falls der Tisch keine Bezeichnung hat, z. b. "B:Raum 6333")'
} until (($Arbeitsplatz -imatch '^b:.+$') -or ($Arbeitsplatz -imatch '^\w{3}\d{4}$'))

$Arbeitsplatz=$Arbeitsplatz -replace('^b:','')


$window = Convert-XAMLtoWindow -XAML $xaml -NamedElement $NamedElements -PassThru
#endregion Code for Convert XAML to Window and Convert XAML to Window

$a = 'Microsoft Windows 10 Enterprise, 2009 (' + $requiredBuild + ')'

$OSCaption = (Get-WmiObject -class Win32_OperatingSystem).Caption
$ReleaseId = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ReleaseId).ReleaseId
$b = "$OSCaption, $ReleaseId (" + [System.Environment]::OSVersion.Version.Build + ')'

$Computername=$env:Computername
$info=[PSCustomObject]@{
  Computername=$Computername
  Arbeitsplatz=$Arbeitsplatz
  WindowsVersion=$b
  Zeitstempel=get-date -format 'yyyy.MM.dd HH:mm:ss'
}
$info | Export-CSV -Path "$Share\$Computername.csv" -NoTypeInformation -Delimiter ';' -Force

if ($a -ne $b) {
  $window.Lbl_EstimatedWinVersion.Content = $a
  $window.Lbl_InstalledWinVersion.Content = $b

  # Show Window
  $result = Show-WPFWindow -Window $window
}