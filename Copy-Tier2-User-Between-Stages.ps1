[CmdletBinding(DefaultParameterSetName = 'dest')]
param(
    #[ValidateSet('source','destination')][Parameter(Mandatory)][Alias('Teil')]$Teil,
    [Parameter(ParametersetName='source',Mandatory)][Alias('u','username')]$samAccountname,
    [Parameter(ParametersetName='source',Mandatory)][Parameter(ParametersetName='dest',Mandatory)][Alias('f','file')]$filename,
    [Parameter(ParametersetName='dest')][Alias('p','password')]$passwort='ChangeMe123456!',
    [Parameter(ParametersetName='source')][Parameter(ParametersetName='dest')][Alias('l')]$logDir='c:\Temp',
    [Parameter(ParametersetName='dest')][Alias('d')]$domain=''
)
$Version='21.203.6'
# 21.202.1 ... Initialversion
# 21.203.1 ... Parametersets zum unterscheiden, ob Source oder Destination-Teil passieren soll
# 21.203.2 ... Passwort im "Klartext" uebergen (Umrechnung auf unicode, base64 passiert im Skript), Logging etwas erweitert
# 21.203.3 ... Syntaxerror korrigiert
# 21.203.4 ... sAMAccountname wird bei dest auch benoetigt (dort wird er aus dem ldif-File gelesen)
# 21.203.5 ... ignored nur noch einmal durchlaufen und die entsprechenden Aktionen ausfuehren
# 21.203.6 ... PrimaryGroup ueber Gruppennamen (nicht ueber PrimaryGroupId aus der Urspungsdomaene setzen)

# ACHTUNG: Im Web ist auch noch zusätzlich der Userprincipalname auszubessern (von @lkwweb.local auf @lkwweb.<stage>)
#          und auch die memberOf

Write-Host('Parameterset: ' + $PSCmdlet.ParameterSetName)
$Teil=$PSCmdlet.ParameterSetName
if ($domain) {
    Write-Host ("Zieldomain angegeben: '$domain'")
    $domaindn='dc='+($domain -replace '\.',',dc=')
    Write-Host ("Zieldomain distinguishedName-Schreibweise: '$domaindn'")
}
$ldifErr=$logDir+'\ldif.err'
if (Test-Path $ldifErr) { 
    Remove-Item $ldifErr -Force -Confirm:$false
}
if ($Teil -ieq 'source') {
  $r="(&(sAMAccountName=${sAMAccountname})(objectClass=User))"
  if (Test-Path $filename) {
      Remove-Item $filename
  }
  ldifde -r $r -f $filename -j $logDir -o objectGUID,objectSid,whenCreated,whenChanged,uSNCreated,uSNChanged,badpasswordTime,lastLogoff,lastLogon,pwdLastSet,lastLogonTimestamp,dSCorePropagationData,badPwdCount,logonCount,lockoutTime,instanceType,accountExpires,objectCategory,sAMAccountType,primaryGroupID 
  if (Test-Path $filename) {
      $priGroupId=(Get-ADUser -filter { sAMAccountname -eq $sAMAccountName } -Properties primarygroupid).PrimaryGroupId
      $primaryGroupName=((Get-ADgroup -filter * -Properties PrimaryGroupToken) | Where-Object { $_.PrimaryGroupToken -eq $priGroupId }).Name
      $c=(get-Content $fileName) -join [Environment]::NewLine
      $c="#PrimaryGroupName:$primaryGroupName"+[Environment]::NewLine + $c
      $c | Out-File $filename -Force -Confirm:$false
      Write-Host ("ldifde Ergebnisdatei: $filename erzeugt")
      Write-Host ("$filename auf ein System fuer die Zieldomaene kopieren")
      Write-Host ("auf dem Zielsystem dann das Skript mit -Teil destination ausfuehren")
      Write-Host ("abweichende Domain mit -domain angeben, Beispiel -domain lkwweb.test")
  } else {
      Write-Host ("Beim Erstellen des ldifde-Datenfiles ist etwas schief gegangen")
  }
}
if ($Teil -ieq 'dest') {
    # was beim Ziel passieren muss ...
    if (Test-Path -Path $filename) {
        $PrimaryGroupName=''
        $item=get-Item $filename
        $c=get-Content $filename
        $ignore=@('memberOf','manager','primaryGroupID')
        $replaceDomainAt=@('userPrincipalName')
        $replaceDomainDN=@('dn','distinguishedName','memberOf','manager')
        $ignored=@()
        $ignore | Foreach-Object { $aktIgnore=$_
            $ignored += $c | Where-Object { $_ -like $aktIgnore+":*" }
            $c = $c | Where-Object { $_ -notlike $aktIgnore+":*" }
        }
        $c = foreach($akt in $c) {
            ($attribut,$wert) = $akt -split ':+\s*',2
            if ($attribut -ieq 'sAMAccountname') {
                $sAMAccountname=$wert
                Write-Host("  sAMAccountname='$sAMAccountname'")
            }
            if ($attribut -ieq '#PrimaryGroupName') {
                $PrimaryGroupName=$wert
                Write-Host("  Primary Group Name='$PrimaryGroupName'")
            }
            if ($domain) {
                $processed=$false
                if ($akt.indexof('::') -gt -1) { $unicode=':' } else { $unicode='' }
                if ($replaceDomainAt -icontains $attribut) {
                    $wert=$wert -ireplace '@.*',('@'+$domain)
                    $attribut + ':' + $unicode + $wert
                    $processed=$true
                }
                if ($replaceDomainDN -icontains $attribut) {
                    Write-Host ("akt=$akt")
                    if ($attribut -ieq 'distinguishedName' -and !($wert)) {
                        $foreach.movenext() | Out-Null
                        $akt=$foreach.current
                        $wert = $akt -ireplace ',dc=.*$',(',' + $domaindn)
                        $attribut + ':' + $unicode
                        $wert
                        $processed=$true
                    } else {
                        $wert=$wert -ireplace ',dc=.*$',(',' + $domaindn)
                        $attribut + ':' + $unicode + $wert
                        $processed=$true
                    }
                }
                if (!$processed) { $akt }
            } else {
                $akt
            }
            
        }
    }
    $unicodePwd=[Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes('"' + $passwort + '"'))
    $c += 'unicodePwd::' + $unicodePwd + [Environment]::NewLine
    $impFilename=$item.Directory.fullname+'\'+$item.BaseName+'-import'+$item.Extension
    $c | Where-Object { $_ } | Out-File $impFilename

    ldifde -i -f $impFilename -t 636 -j $logDir
    if (Test-Path ($logDir + '\ldif.err')) {
        Write-Host ("Fehler beim Import mit ldifde!")            
        exit 1
    }
    Write-Host ("Warte 60 Sekunden, damit die AD-Replikation sicher abgeschlossen ist")
    Start-Sleep -Seconds 60
    $user=get-ADuser -filter { sAMAccountname -eq $sAMAccountname } -Properties PrimaryGroupID,manager
    $allGroups=Get-ADGroup -filter * -Properties PrimaryGroupToken

    $ignored | Foreach-Object {
        ($attribut,$wert)=$_  -split ':+\s*',2
        if ($domain -and ($replaceDomainDN -icontains $attribut)) {
            $wert=$wert -ireplace ',dc=.*$',(',' + $domaindn)
        }
        # memberOf
        if ($attribut -ieq 'memberOf') {
            Write-Host ("Setze Gruppe '$wert'")
            try {
                $grp=get-ADGroup -Identity $wert -ErrorAction Stop
                try {
                    Add-ADGroupMember -Identity $grp -Members $user
                } catch {
                    Write-Host("Konnte User nicht zur Gruppe '$wert' hinzufuegen ...")
                }
            } catch {
                Write-Host ("Gruppe '$wert' nicht gefunden")
            }
        }
        # manager
        if ($attribut -ieq 'manager') {
            $managerDN=$_ -replace '^manager:\s*',''
            $managerUser = Get-ADUser $managerDN
            if ($managerUser) {
                $user | Set-ADUser -Manager $managerDN
            } else {
                Write-Host("Manager '$managerDN' nicht gefunden, daher wird kein Manager hinterlegt")
            }
    
        }
    }

    # primary Group
    if ($PrimaryGroupName) {
        $priGroup=(Get-ADGroup -Filter { Name -eq $PrimaryGroupName } -Properties PrimaryGroupToken)
        if ($priGroup) {
            $priGroupId=$priGroup.PrimaryGroupToken
            $removeGroup=$allGroups | Where-Object { $_.PrimaryGroupToken -eq ($user.PrimaryGroupID)}
            Write-Host ("Setze primary Group '$PrimaryGroupName', PrimaryGroupId: '$priGroupId'")
            if ($user.PrimaryGroupID -ne $priGroupId) {
                Add-ADGroupMember -Identity $priGroup -Members $user
                $user | Set-ADuser -Replace @{PrimaryGroupID=$priGroupId}
                if ($removeGroup) {
                    Remove-ADGroupMember -Identity $removeGroup -Members $user -Confirm:$false
                }
            }
        } else {
            Write-Host ("Gruppe '$PrimaryGroupName' nicht gefunden")
        }
    }
} else {
    Write-Host ("Datenfile $filename nicht gefunden")
}
