param(
  $Path='C:\Temp',
  [Alias('uf')]$userFile='KencubeUserExport.csv',
  [Alias('gf')]$groupFile='KencubeGroupExport.csv',
  [Alias('gd','groupsDefinition')]$groupDefinition='Kencube-Gruppen.csv',
  [switch]$simulate
)

$Version = '20.1216.2'
# 20.1215.1 ... Gruppen aus CSV lesen und als ExtensionAttribute2 nur noch die IDM-ID (ohne .us) ausgeben
# 20.1215.2 ... diverse Korrekturen
# 20.1216.1 ... Check auf simulate an die richtige Stelle verschoben
# 20.1216.2 ... Path am Anfang vom Skript noch hartcodiert gewesen  - entfernt

function Schreibe-Debug
{
	PARAM(
		[string]$dbgText,
		[switch]$neuesFile = $false,
		[switch]$writehost = $true
	)
	[string]$h = (Get-Date -uformat "%Y.%m.%d %H:%M:%S").tostring()
	$dbgText = $h + ": " + $dbgText
	if ($neuesFile)
	{
		$dbgText | Out-File $DebugFilename
	}
	else
	{
		$dbgText | Out-File $DebugFilename -append
	}
	if ($writehost) {
		Write-Host ("DEBUG: $dbgText")
	}
}

filter ArrayToHash
{
    Param(
        $Property
    )

    begin { $hash = @{} }
    process { $hash[$_.$Property] = $_ }
    end { return $hash }
}


Import-Module lkw-scp

#$Path = 'C:\Temp'
$DebugFileName="$Path\KencubeInfos-"+((Get-Date -uformat "%Y.%m.%d-%H-%M-%S").tostring())+".txt"
Schreibe-Debug -dbgText "Starte Programm (groupDefinition='$groupDefinition',userFile=$userFile,groupFile=$groupFile,simulate=$simulate" -neuesFile
if (!(Test-Path $groupDefinition)) {
  $groupDefinition="$Path\$groupDefinition"
  if (!(Test-Path $groupDefinition)) {
    $groupDefinition=$null
  }
}

if ($groupDefinition) {
  $SearchBaseAll = @(
    'OU=KUF,dc=lkw-walter,dc=com',
    'OU=WND,dc=lkw-walter,dc=com'
  )

  $allGroups = Get-ADGroup -Filter * -Properties Displayname | Where { $_.Displayname }
  $hashGroups = $allGroups | ArrayToHash -Property 'Displayname' 
  $Users = $SearchBaseAll | Foreach-Object {
      $CurrentBase = $_
      Get-Aduser -SearchBase $CurrentBase -Filter * -Properties samAccountName,GivenName,SurName,proxyAddresses,extensionAttribute2,extensionAttribute5 | Where-Object {($_.extensionAttribute2) -and ($_.Enabled)} | Select-Object samAccountName,GivenName,SurName,proxyAddresses,@{n='extensionAttribute2';e={$_.extensionAttribute2 -replace '\.us$',''}},extensionAttribute5
  }
  $hashUsers = $Users | ArrayToHash -Property 'sAMAccountname'

  $Export = $Users | Foreach-Object {
      $CurrentUser = $_
      $Email = ($CurrentUser.proxyAddresses | Where-Object {$_ -clike "SMTP:*"}) -replace "SMTP:",""

      $a = [PSCustomObject]@{
          samAccountName = $CurrentUser.samAccountName
          GivenName = $CurrentUser.GivenName
          Surname = $CurrentUser.Surname
          Email = $Email
          extensionAttribute2 = $CurrentUser.extensionAttribute2
      }
      $a
  }

  $Export | Export-CSV -Path "$Path\$userFile" -Delimiter ";" -NoTypeInformation -Encoding UTF8

  #AD Group Infos
    $ADGroups = (Import-Csv -Path $groupDefinition -Delimiter ';' -Encoding 'UTF8').Displayname | where { $_ }
    $erg=@()
    Foreach ($Group in $ADGroups) {
      $cg = $hashGroups[$Group]
      $cgm = Get-ADGroupMember $cg -Recursive
      Schreibe-Debug ("Aktuelle Gruppe = $($cg) und hat $($cgm.count) Mitglieder")

      $b = foreach ($user in $cgm) {
        $cu = $hashUsers[$user.samAccountName]
        If ($cu) {
          $cu.extensionAttribute2
        } Else {
          Schreibe-Debug ("ACHTUNG falscher User gefunden: $($user.samaccountname)")
        }
      }

      $a = [PSCustomObject]@{
        GroupName = $cg.Name
        GroupSamAccountName = $cg.samAccountName
        MemberCount = @($cgm).count
        Members = $b -Join ","

      }
      $erg+=$a
    }

    $erg | export-csv -Path "$Path\$groupFile" -Delimiter ";" -NoTypeInformation -Encoding UTF8


  $IntranetKenCube=@{Hostname = '77.244.241.119'; Username='lwdatatransfer'; Password='v5aIzWcudASqPMuL';
      sshKey='ssh-rsa 3072 93:6b:0b:c6:e7:5b:3d:18:e4:02:c1:6e:0c:6b:99:ec'; FotoDir='/home/lwdatatransfer/profileimages/'; UserDir='/home/lwdatatransfer/adsyncfiles/'}

  $secure_pwd = $IntranetKenCube.password | ConvertTo-SecureString -AsPlainText -Force

  if (!($simulate)) {
    $ScpCred = New-Object System.Management.Automation.PSCredential -ArgumentList $IntranetKenCube.Username, $secure_pwd

    $ScpSession = New-ScpSession -hostname ($IntranetKenCube.Hostname) -credential $ScpCred -sshKey ($IntranetKenCube.sshKey)

    $kenCubeReturn=Send-ScpITem -session $ScpSession -localPath "$Path\$userFile" -remotePath $UserDir
    if ($kenCubeReturn.success) {
      Schreibe-Debug ("Transferieren von '$Path\$userFile' mit SCP zu KenCube erfolgreich")
    } else {
      $mitFehler=$true
      Schreibe-Debug ("FEHLER! Transferieren von '$Path\$userFile' mit SCP zu KenCube NICHT erfolgreich (" + ($kenCubeReturn.Details | Convertto-Json) +")")
    }

    $kenCubeReturn=Send-ScpITem -session $ScpSession -localPath "$Path\$groupFile" $UserDir
    if ($kenCubeReturn.success) {
      Schreibe-Debug ("Transferieren von '$Path\$groupFile' mit SCP zu KenCube erfolgreich")
    } else {
      $mitFehler=$true
      Schreibe-Debug ("FEHLER! Transferieren von '$Path\$groupFile' mit SCP zu KenCube NICHT erfolgreich (" + ($kenCubeReturn.Details | Convertto-Json) +")")
    }
  }
} else {
  Write-Error -Message ("'$groupDefinition' nicht gefunden") -Category ObjectNotFound
}