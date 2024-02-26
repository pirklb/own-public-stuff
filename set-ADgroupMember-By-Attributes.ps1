param(
    [Alias('file','f')]$csvFile='c:\temp\Mapping-Attribut-Gruppenname.csv'
)
$Version='20.928.1'
function set-ADgroupMembershipByAttributes {
    param(
        [Alias('file','f')]$csvFile='c:\temp\Mapping-Attribut-Gruppenname.csv'
    )
    $extOU='OU=Users,OU=EXTERN,DC=lkw-walter,DC=com'
    $groupOU='OU=Groups,OU=!RESS,DC=lkw-walter,DC=com'
    Write-Verbose("set-ADgroupMember-By-Attributes, Version=$Version")
    $users=get-aduser -Filter { samaccountname -like '*' } -SearchBase $extOU -properties *

    $csv=Import-Csv -Delimiter ';' -Path $csvFile
    $grpCSV=$csv | Group-Object -Property Gruppenname

    $grpCSV | Foreach-Object {
        $aktGroup=$_
        $groupName = $aktGroup.Name
        Write-Verbose ("Verarbeite Gruppe '$groupName' (enthaelt " + $aktGroup.Count + ' Regeln)')
        try { 
            $grp=get-adgroup ($groupName) -ErrorAction Stop 
        } catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] { 
            Write-Verbose ("  Gruppe hat noch nicht existiert, daher wurde sie angelegt")
            $grp=New-ADGroup -Name ($groupName) -Path $groupOU -GroupScope Global -GroupCategory Security `
            -Description 'automatische Gruppenmitgliedschaft anhand von Attributwert' -PassThru 
        }
        $info=@()
        $grpUsers=$aktGroup.Group | Foreach-Object {
            $zeile=$_
            $attrName=$zeile.Attributname
            $attrWert=$zeile.attributwert
            $info += '(' + $attrName + ' -like "' + $attrWert + '")'
            $users | Where-Object { $_.$attrName -like $attrWert}
        }
        $infoString = $info -join ' -or '
        Write-Verbose("    Regeln: $infoString")
        $grp | Set-ADGroup -Replace @{info=$infoString}
        $grpMembers = $grp | Get-ADGroupMember
        $removeMembers = Compare-Object -ReferenceObject $grpUsers -DifferenceObject $grpMembers -Property sAMAccountname -Passthru `
        | Where-Object { $_.Sideindicator -eq '=>' } 
        if ($removeMembers) {
            Write-Verbose("  entferne " + $removeMembers.Count + " falsche Mitglieder aus der Gruppe")
            Remove-ADGroupMember -Identity $grp -Confirm:$false -Members $removeMembers
        }
        $grpUsers = $grpUsers | sort-Object -Property sAMAccountname -unique

        $sollAnzahl=$grpUsers.Count
        Write-Verbose("  Fuege Mitglieder hinzu, Gruppe soll $sollAnzahl Mitglieder haben")
        Add-ADGroupMember -Identity ($grp.distinguishedName) -Members $grpUsers
        $istAnzahl = (Get-ADGroupMember -Identity $grp).Count
        Write-Verbose("  Gruppe hat jetzt $istAnzahl Mitglieder")
        if ($istAnzahl -eq $sollAnzahl) {
            Write-Verbose("  OK:Korrekte Anzahl Mitglieder")
        } else {
            Write-Error -Message "NOK: Falsche Anzahl Mitglieder (erwartet: $sollAnzahl, tatsaechlich: $istAnzahl)"
        }
    }
}

set-ADgroupMembershipByAttributes -csvFile $csvFile
