[CmdletBinding()]
Param(
  [Parameter(Mandatory,Helpmessage='Fuer welchen Benutzer ist der Adminuser - Benutzername in der Domaene lkw-walter.com')][Alias('u')]$username,
  [Parameter(Mandatory)][ValidateSet('DomainAdmin','ServerAdmin','ClientAdmin')]$Type,
  [Parameter(HelpMessage='In welcher Domaene soll der Adminuser angelegt werden')][Alias('d','domaene')][string]$domain='lkw-walter.com',
  [Parameter(Helpmessage='soll der Benutzer in der Domaene ueberprueft werden? Geht nur, wenn der Admin Account  fuer die Domaene des Computers, wo das Skript ausgefuehrt wird, angelegt werden soll und ist nicht notwendig, wenn SNOW die Funktion aufruft (dort stellt SNOW sicher, dass der Benutzer mit username existiert), andernfalls muessen die Parameter surname und givenname uebergeben werden')][Switch]$checkUser,
  [Alias('password')][string]$passwort='ChangeMe123456!',
  [string]$surname=$username+'-Admin',
  [string]$givenname=$username+'-'+$Type,
  [Parameter(HelpMessage='Handelt es sich um einen Lieferanten? UPN lautet dann auf @partner.local')][switch]$lieferant,
  [Parameter(HelpMessage='In welche AD-Gruppen soll der Admin-User aufgenommen werden (sofern die AD-Gruppe im jeweiligen AD existiert)')][string[]]$groups=@()
)
  
$Version='20.1222.3'
# History
#   20.922.1 ... Primary Gruppe vom normalen Benutzer "erben"
#   20.1023.1 ... Parameter (Switch) Lieferant (damit bekommt man einen UPN @partner.local)
#   20.1106.1 ... Namen wie in Get-Usernames festgelegt (zumindest bei intern sollte es klappen)
#   20.1110.1 ... neue Version von Get-Usernames (die Daten des Admin-Users werden frisch eingelesen, weil nicht alle Infos beim uebergebenen User dabei sind)
#   20.1110.2 ... new-Adminuser protokolliert, ob die Daten vom "normalen User" gelesen werden
#   20.1120.1 ... Parameter passwort (Default ChangeMe123456!)
#   20.1210.1 ... OU abhängig von Domäne und AdminType
#   20.1211.1 ... Tippfehler bei CheckUser korrigiert
#   20.1211.2 ... Parameter -groups hinzugefuegt
#   20.1211.3 ... Bestehender Adminuser wird ebenfalls in die angegeben Gruppen hinzugefuegt
#   20.1211.4 ... bei .3 wurde die falsche Variable verwendet ($adUser statt $bestehenderAdmin)
#   20.1211.5 ... Vergleich bei bestehenderAdmin war falsch
#   20.1211.6 ... Bestehender Adminuser - Check Disabled, falscher Variablenname verwendet
#   20.1218.1 ... Nach Anlage User 60 Sekunden warten (damit der Adminaccount sicher im AD gefunden wird - war frueher nicht notwendig)
#   20.1222.1 ... Fix gegen einen bestimmten DC arbeiten
#   20.1222.2 ... Fuer Lieferanten in lkw-walter.com upn mit @partner.local enden lassen
#   20.1222.3 ... PrimaryGroupkontrolle korrigiert (Tippfehler: falsch extUser.Primary...)
Import-Module ActiveDirectory

#region aus Ad-Account-Namen.ps1 (20.1222.1)
$allAdminTypes=@{'Server Admin'='sa';'Domain Admin'='da';'Client Admin'='ca'}
function get-UserNames {
  [CmdletBinding()]
  param(
      [Parameter(Mandatory)]$aktUser,
      $domain='lkw-walter.com',
      [Parameter(HelpMessage='Gegen welchen Domaincontroller soll gearbeitet werden. Wenn kein bestimmter angegeben wird, arbeitet die Funktion die ganze Zeit gegen einen bestimmten, der am Anfang der Funktion ermittelt wird')][Alias('DC')]$DomainController=$null
  )
  if (!$DomainController) {
    $DomainController=(@(Get-ADDomainController -Discover)[0]).hostname
  }
  if (!$aktUser.msExchExtensionAttribute31) {
    $tmpUn=$aktUser.sAMAccountname
    $aktUser=get-ADUser -filter { samaccountname -eq $tmpUn } -Properties * -Server $DomainController
  }
  $normUserName=($aktUser.msExchExtensionAttribute31 -split ';')[0]
  $admt=($aktUser.msExchExtensionAttribute31 -split ';')[1]
  $admkurz=$allAdminTypes.$admt
  $normUser=get-aduser -filter { sAMAccountname -eq $normUserName } -properties * -Server $DomainController
  if ($normUser) {
      Write-Verbose("Infos vom normalen Benutzer ('$normUsername')")
      $vn=$normuser.givenname
      $nn=$normuser.surname
      $norm_e2=$normUser.extensionAttribute2
      $norm_company=$normUser.company
      Write-Verbose("    Vorname: '$vn', Nachname: '$nn'")
      Write-Verbose("    extensionAttribute2:'$norm_e2'")
      Write-Verbose("    company:$norm_company'")
      $name="$nn, $vn - $admt".Replace('ä','ae').Replace('Ä','Ae').Replace('ö','oe').Replace('Ö','Oe').Replace('ü','ue').Replace('Ü','Ue').Replace('ß','ss')
      $e2=($norm_e2 -split '\.')[0] + '.' + $admkurz
      $sAM=$normuser.sAMAccountname + "-$admkurz"
      $upn="$sAM@$domain"
      Write-Verbose("    extensionAttribute5:'$($normuser.extensionAttribute5)'")
      if ($normUser.extensionAttribute5 -match '^9\d{4}$') {
          $acct='EXTERN'
          $name=$name + " (EXTERN)"
      } elseif ($normUser.extensionAttribute5) {
          $acct='INTERN'
      } else {
          $acct='LIE'
          $name=$name + ' (LIE)'
          if ($domain -ieq 'lkw-walter.com') {
            $upn="$sAM@partner.local"
          }
      }
      Write-Verbose("        daher Accounttype:$acct")
      if ($acct -eq 'LIE') {
          $description="$nn, $vn - $admt (LIE, $norm_company)".Replace('ä','ae').Replace('Ä','Ae').Replace('ö','oe').Replace('Ö','Oe').Replace('ü','ue').Replace('Ü','Ue').Replace('ß','ss')
      } else {
          $description=$name
      }
      $cn=$name
      $displayname=$name

      Write-Verbose("Infos vom Adminbenutzer ('$sAM')")
      Write-Verbose("    AccountType: '$acct'")
      Write-Verbose("    name, cn, displayname:'$name'")
      Write-Verbose("    Description:'$description'")
      Write-Verbose("    extensionAttribute2:'$e2'")
      Write-Verbose("    userprincipalname:'$upn'")
      Write-Verbose("    company:'$norm_company'")
      $zeile=@{
          Domain=$domain;
          AccountType=$acct;
          cn=$cn;
          Description=$description;
          Displayname=$displayname;
          extensionAttribute2=$e2;
          givenName=$vn;
          name=$name;
          sAMAccountname=$sAM;
          sn=$nn;
          upn=$upn;
          company=$norm_company
      }
      $zeile
  } else {
      Write-Host ("Benutzer '$normusername' (fuer $($aktUser.sAMAccountname)) nicht gefunden")
  }
}
#endregion

function new-Adminuser {
  [CmdletBinding()]
  Param(
      [Parameter(Mandatory,Helpmessage='Fuer welchen Benutzer ist der Adminuser - Benutzername in der Domaene lkw-walter.com')][Alias('u')]$username,
      [Parameter(Mandatory)][ValidateSet('DomainAdmin','ServerAdmin','ClientAdmin')]$Type,
      [Parameter(HelpMessage='In welcher Domaene soll der Adminuser angelegt werden')][Alias('d','domaene')][string]$domain='lkw-walter.com',
      [Parameter(HelpMessage='Gegen welchen Domaincontroller soll gearbeitet werden. Wenn kein bestimmter angegeben wird, arbeitet die Funktion die ganze Zeit gegen einen bestimmten, der am Anfang der Funktion ermittelt wird')][Alias('DC')]$DomainController=$null,
      [Parameter(Helpmessage='soll der Benutzer in der internen Domaene ueberprueft werden? Geht nur, wenn der Admin Account ebenfalls fuer lkw-walter.com angelegt werden soll und ist nicht notwendig, wenn SNOW die Funktion aufruft (dort stellt SNOW sicher, dass der Benutzer mit username existiert), andernfalls muessen die Parameter surname und givenname uebergeben werden')][Switch]$checkUser,
      [Alias('password')][string]$passwort='ChangeMe123456!',
      [string]$surname=$username+'-Admin',
      [string]$givenname=$username+'-'+$Type,
      [Parameter(HelpMessage='Handelt es sich um einen Lieferanten? UPN lautet dann auf @partner.local')][switch]$lieferant,
      [Parameter(HelpMessage='In welche AD-Gruppen soll der Admin-User aufgenommen werden (sofern die AD-Gruppe im jeweiligen AD existiert)')][string[]]$groups=@()
  )
  Write-Host ("newAdminUser, Version $Version")
  if (!$DomainController) {
    $DomainController=[string]((@(Get-ADDomainController -Discover -Writable -NextClosestSite)[0]).hostname)
  }
  Write-Host ("Domaincontroller='$DomainController' fuer Domaene '$domain'")
  $userInfo=@{
      DomainAdmin=@{kuerzel='da';msExchExtensionAttribute31='Domain Admin';
          OU=@{'lkw-walter.com'='ou=Service Accounts,ou=!RESS';
               'lkwweb.local'='OU=Accounts,OU=Tier 0,OU=Admin';
               'lkwweb.test'='OU=Accounts,OU=Tier 0,OU=Admin';
               'lkwweb.dev'='OU=Accounts,OU=Tier 0,OU=Admin'}};
      ServerAdmin=@{kuerzel='sa';msExchExtensionAttribute31='Server Admin';
          OU=@{'lkw-walter.com'='ou=Service Accounts,ou=!RESS';
               'lkwweb.local'='OU=Accounts,OU=Tier 1,OU=Admin';
               'lkwweb.test'='OU=Accounts,OU=Tier 1,OU=Admin';
               'lkwweb.dev'='OU=Accounts,OU=Tier 1,OU=Admin'}};
      ClientAdmin=@{kuerzel='ca';msExchExtensionAttribute31='Client Admin';
          OU=@{'lkw-walter.com'='ou=Service Accounts,ou=!RESS';
               'lkwweb.local'='OU=Accounts,OU=Tier 1,OU=Admin';
               'lkwweb.test'='OU=Accounts,OU=Tier 1,OU=Admin';
               'lkwweb.dev'='OU=Accounts,OU=Tier 1,OU=Admin'}}
  }
  $samAccountName=$username+'-'+ $userInfo.$Type.kuerzel
  $msExchExtensionAttribute31=$username+';'+$userInfo.$Type.msExchExtensionAttribute31
  $andererAdminuser=get-ADUser -filter { (sAMAccountName -ne $samAccountName) -and (msExchExtensionAttribute31 -eq $msExchExtensionAttribute31) } -Server $DomainController
  $bestehenderAdminuser=get-ADUser -filter { (sAMAccountName -eq $samAccountName) } -Server $DomainController
  if ($checkUser -and ($domain -ieq ((Get-WmiObject Win32_Computersystem).domain))) {
    $normalerUser=get-Aduser -filter { samAccountname -eq $username } -Properties *  -Server $DomainController | Where-Object { $_.sAMAccountName -ieq $username } 
    if ($normalerUser) {
      $primaryGroup=$normalerUser.primaryGroup
    } else {
      $primaryGroup=''
    }
    Write-Host ("primaryGroup vom normalen User: $primaryGroup")
  } else { 
    $normalerUser=@{surname=$surname;givenName=$givenName}
    Write-Host ("Normaler User wurde nicht gecheckt, Vorname='$($normalerUser.givenName)', Nachname='$($normalerUser.surname)'")
  }
  if (($normalerUser | measure-object).count -eq 1) {
    Write-Host ('Es wurde genau ein User gefunden, fuer den der Adminuser angelegt werden soll, daher fortfahren');
    $msExchExtensionAttribute31=$username+';'+$userInfo.$Type.msExchExtensionAttribute31
    Write-Host ("Adminuser bekommt msExchExtensionAttribute31='$msExchExtensionAttribute31'")
    $sn=$normalerUser.surname
    $gn=$normalerUser.givenName
    $upn=$samAccountName + '@' + $domain
    if ($lieferant -and $domain -ieq 'lkw-walter.com') {
      $upn=$samAccountName + '@partner.local'
    }
    $cn="$sn $gn, " + $userInfo.$Type.msExchExtensionAttribute31
    $name=$cn
    $Description=$cn
    $Displayname=$cn
    $PassWD=$passwort | ConvertTo-SecureString -AsPlainText -Force

    $d2=$domain -split '\.'
    $d2=$d2 | ForEach-Object { 'dc='+$_ }
    $domaindistinguishedName = $d2 -join ','
    $OUName=$userInfo.$Type.ou.$domain + ",$domaindistinguishedname"
    Write-Host ("OU fuer Adminuser: '$OUName'")
    $OU=get-ADOrganizationalUnit $OUName -Server $DomainController
    if ((!$andererAdminUser) -and (!$bestehenderAdminuser)) {
      Write-Host ('Es wurde auch noch kein bestehender Adminuser mit dem Typ "' + $userInfo.$Type.msExchExtensionAttribute31 + '" gefunden, daher fortfahren');
      Write-Host('Anlage Admin User fuer "' + $username + '", Type "' + $Type + '":') 
      Write-Host('sAMAccountname='+$samAccountName)
      Write-Host('Userprincipalname=' + $upn)
      Write-Host('cn='+$cn)
      Write-Host('name=' + $name)
      Write-Host('Description='+$Description)
      Write-Host('Displayname='+$Displayname)
      Write-Host('msExchExtensionAttribute='+$msExchExtensionAttribute31)
      $adUser=New-ADUser -Name $name -Surname $sn -GivenName $gn -UserPrincipalName $upn `
        -Description $Description -DisplayName $Displayname -SamAccountName $samAccountName `
        -AccountPassword $PassWD -Path $ou -enabled:$true `
        -OtherAttributes @{'msExchExtensionAttribute31'=$msExchExtensionAttribute31} -PassThru -Server $DomainController
      try { $extUsers=get-adgroup 'externe-Domainusers' -Properties PrimaryGroupToken -ErrorAction Stop  -Server $DomainController } catch { }
      if ($extUsers -and ($primaryGroup -ilike $extUsers)) {
        Write-Host ("der normale User ist Mitglied der externe-Domainusers (PrimaryGroupToken='$($extUsers.PrimaryGroupToken)'), daher soll der Adminaccount auch dort hinein")
        Add-ADGroupMember -Identity ($extUsers.DistinguishedName) -Members $adUser  -Server $DomainController
        $adUser | Set-ADuser -Replace @{PrimaryGroupID=$extUsers.PrimaryGroupToken}  -Server $DomainController
        $DomUsers=get-ADGroup 'Domain Users'  -Server $DomainController
        $tmpPriToken=(Get-ADuser $samAccountName -Property PrimaryGroupID  -Server $DomainController).PrimaryGroupID
        Remove-ADGroupMember -Identity ($DomUsers.DistinguishedName) -Members $adUser -Confirm:$false  -Server $DomainController
        Write-Host ("Adminuser hat die PrimaryGroup:'$($tmpPriToken)'")
      }
      if ($groups) { 
        foreach ($group in $groups) {
          try {
            $aktGrp=get-ADgroup $group -ErrorAction Stop  -Server $DomainController
            if ($aktGrp) {
              if (@($aktGrp).Count -eq 1) {
                Write-Host ("Gruppe '$group' eindeutig gefunden: '$($aktGrp.Name)', daher User zur Gruppe hinzufuegen")
                Add-ADGroupMember -Identity ($aktGrp.DistinguishedName) -Members $adUser -Server $DomainController
              } else {
                Write-Host ("Gruppe '$group' NICHT eindeutig gefunden: $(@($aktGrp).Count) moegliche Gruppen gefunden, daher User NICHT zur Gruppe hinzufuegen")
              }
            } else {
              # wahrscheinlich ist das hier unnoetig, weil er eh nie daher kommt - weil das try-catch davor rausfaellt
              Write-Host("Gruppe '$group' nicht gefunden")
            }
          } catch {
            Write-Host("Gruppe '$group' nicht gefunden")
          }
        }
      }
      # hier jetzt die Attribute richtig setzen, wie in Get-Usernames festgelegt
      $aktUser=$adUser
      $neueInfos=get-UserNames -aktUser $aktUser -domain $domain -DomainController $DomainController
      if ($aktUser.name -ine $neueInfos.name) {
        $aktUser = $aktUser | Rename-ADObject -NewName $neueInfos.name -PassThru  -Server $DomainController # aendert cn, name und distinguishedname 
      }
      $aktUser | Set-ADuser -company ($neueInfos.company) -description ($neueInfos.Description) -Displayname ($neueInfos.Displayname) `
        -GivenName ($neueInfos.givenname) -Surname ($neueInfos.sn) -Replace @{extensionAttribute2=($neueInfos.extensionAttribute2)} -Server $DomainController
      if ($aktUser.sAMAccountname -ine $neueInfos.sAMAccountname) {
        $aktUser | Set-ADuser -sAMAccountname ($neueInfos.sAMAccountname) -userprincipalname ($neueInfos.upn) -Server $DomainController
      }
    } else {
      if ($bestehenderAdminuser -and (!$andererAdminuser)) {
        Write-Host ('Es existiert bereits ein entsprechender Adminuser...')
        $ou_d=$ou.DistinguishedName
        $bA_d=$bestehenderAdminuser.DistinguishedName
        if ($bA_d -imatch ("$ou_d$")) {
          Write-Host ('  ... und dieser befindet sich in der richtigen OU, setze zur Sicherheit die entsprechenden Attribute')
          Write-Host('Userprincipalname=' + $upn)
          Write-Host('cn='+$cn)
          Write-Host('name=' + $name)
          Write-Host('Description='+$Description)
          Write-Host('Displayname='+$Displayname)
          Write-Host('msExchExtensionAttribute='+$msExchExtensionAttribute31)
          Set-ADUser -Identity $bA_d -Replace @{sn=$sn;GivenName=$gn;UserPrincipalName=$upn;`
            Description=$Description;DisplayName=$Displayname;msExchExtensionAttribute31=$msExchExtensionAttribute31} -Server $DomainController
          if ($bestehenderAdminUser.Name -ine $name) {
            Write-Host('name ist geaendert, daher auch noch Rename-ADObject ausfuehren')
            Rename-ADObject -Identity $bA_d -NewName $name -Server $DomainController
          }
          if (!($bestehenderAdminUser.enabled)) {
            Write-Host('   ... aber der Adminuser ist DISABLED - wurde NICHT geaendert!')
          }
          if ($groups) { 
            foreach ($group in $groups) {
              try {
                $aktGrp=get-ADgroup $group -ErrorAction Stop -Server $DomainController
                if ($aktGrp) {
                  if (@($aktGrp).Count -eq 1) {
                    Write-Host ("Gruppe '$group' eindeutig gefunden: '$($aktGrp.Name)', daher User zur Gruppe hinzufuegen")
                    if (!((get-ADGroupMember -Identity ($aktgrp.DistinguishedName) -Server $DomainController).distinguishedname -contains ($bestehenderAdminuser.DistinguishedName))) {
                      Add-ADGroupMember -Identity ($aktGrp.DistinguishedName) -Members $bestehenderAdminuser -Server $DomainController
                    } else {
                      Write-Host ("  Adminuser ist schon in der Gruppe, daher nichts machen")
                    }
                  } else {
                    Write-Host ("Gruppe '$group' NICHT eindeutig gefunden: $(@($aktGrp).Count) moegliche Gruppen gefunden, daher User NICHT zur Gruppe hinzufuegen")
                  }
                } else {
                  # wahrscheinlich ist das hier unnoetig, weil er eh nie daher kommt - weil das try-catch davor rausfaellt
                  Write-Host("Gruppe '$group' nicht gefunden")
                }
              } catch {
                Write-Host("Gruppe '$group' nicht gefunden")
              }
            }
          }
        } else {
          Write-Host(' ... dieser befindet sich aber in einer falschen OU, mache daher nichts.')
          Write-Host("     erwartete OU=$ou_d")
          Write-Host("     tatsaechliche OU=$bA_d")
        }
      } else {
        Write-Host ("ACHTUNG: es existiert ein entsprechender Adminuser, dessen sAMAccountname NICHT '$sAMAccountName' lautet, sondern '" + $andererAdminUser.sAMAccountname + '"')
      }
    }
  } else {
    write-Error -Message "Fuer Benutzername '$username' kann kein eindeutiger Benutzer im Active Directory ermittelt werden" -Category InvalidArgument
  }
}

$params=@{username=$username; type=$type;givenname=$givenname;surname=$surname;checkUser=$checkUser;passwort=$passwort;lieferant=$lieferant;domain=$domain;groups=$groups;DomainController=[string]((@(Get-ADDomainController -Discover -Writable -NextClosestSite)[0]).hostname)}
new-Adminuser @params

# geht nicht, weil in PSBoundparameters nur tatsaechlich mitgegebene Parameter existieren
#new-Adminuser @PSBoundparameters