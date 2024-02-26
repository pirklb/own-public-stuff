param(
    [ValidateSet('Add','Remove')]$operation='Add',
    [Parameter(Helpmessage='Welches Matching Property ist im inputfile angegeben (mail ... primaere Mailadresse, username ... AD-Benutzername (sAMAccountname)')][ValidateSet('username','mail')][Alias('property','p','mp')]$matchProperty='mail',
    $roleDN='cn=IT_ADS_Group_LW_Gruppen_P_O_250300,cn=Level10,cn=RoleDefs,cn=RoleConfig,cn=AppConfig,cn=UserApplication,cn=DriverSet,o=System',
    $Comment='importiert aus CSV',
    $resultfile='C:\Temp\IDM-Import-RoleAssignment.csv',
    $inputfile='',
    $groupname=''
)
$Version='21.421.1'
# 20.1216.1 ... erste Version
# 20.1216.2 ... beim Export einen falschen Variablennamen als Dateiname angegeben gehabt
# 20.1216.3 ... Standard-roleDN war kein DN
# 20.1217.1 ... User muss ebenfalls in ldap-Notation angegeben werden
# 20.1217.2 ... Parameter matchProperty (mail, username) aufgenommen - welches Attribut steht im inputfile
# 21.201.1 ... Trim bei den Werten aus dem CSV eingefuegt (Parameteruebergabe von roleDN funktioniert nicht richtig "[System.Object]"" landet im Ergebnis-CSV)
# 21.421.1 ... Parameter groupname eingebaut (die Mitglieder der AD-Gruppe werden als Input verwendet - wenn Inputfile nicht angegeben wurde!, sonst gewinnt Inputfile)

function Test-IsValidDN
{
    <#
        .SYNOPSIS
            von https://pscustomobject.github.io/powershell/howto/identity%20management/PowerShell-Check-If-String-Is-A-DN/ - funktioniert nur fuer AD
            Cmdlet will check if the input string is a valid distinguishedname.

        .DESCRIPTION
            Cmdlet will check if the input string is a valid distinguishedname.

            Cmdlet is intended as a dignostic tool for input validation

        .PARAMETER ObjectDN
            A string representing the object distinguishedname.

        .EXAMPLE
            PS C:\> Test-IsValidDN -ObjectDN 'Value1'

        .NOTES
            Additional information about the function.
    #>

    [OutputType([bool])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias('DN', 'DistinguishedName')]
        [string]
        $ObjectDN
    )

    # Define DN Regex
    [regex]$distinguishedNameRegex = '^(?:(?<cn>CN=(?<name>(?:[^,]|\,)*)),)?(?:(?<path>(?:(?:CN|OU)=(?:[^,]|\,)+,?)+),)?(?<domain>(?:DC=(?:[^,]|\,)+,?)+)$'

    return $ObjectDN -match $distinguishedNameRegex
}

#if (Test-IsValidDN -ObjectDN $roleDN) {
    $identitySuffix=',ou=pers,ou=users,o=idvault'

    $operation=$operation.substring(0,1).toupper()+$operation.substring(1).tolower() # 1. Zeichen gross, alle anderen klein

    $allUsers=get-ADuser -filter "*" -properties extensionAttribute2,mail,proxyAddresses

    if ($inputfile -and (Test-Path -Path $inputfile)) {
        $i=Import-Csv -Path $inputFile -Delimiter ';'
        $u=$i | Foreach-Object {
            $aktRow=$_
            if ($matchProperty -ieq 'mail') { $tmp=$allUsers | Where-Object { $aktRow.mail.Trim() -ieq $_.mail } }
            if ($matchProperty -ieq 'username') { $tmp=$allUsers | Where-Object { $aktRow.username.Trim() -ieq $_.sAMAccountname } }
            if (@($tmp).Count -eq 1) {
                $tmp
            } else {
                Write-Host ("finde keinen eindeutigen User fuer '$($aktRow.$matchProperty)'")
            }
        }
    } else {
        Write-Host "Inputfile '$inputfile' nicht gefunden (oder keines angegeben)"
        if ($groupname) {
            # Mitglieder der Gruppe $groupname die Rolle zuweisen, wenn kein Inputfile angegeben wurde      
            $group=get-adgroup $groupname
            if ($group) {
                $groupMembers=$group | Get-ADGroupMember
                $u=foreach ($mbr in $groupmembers) {
                    $allUsers | Where-Object { $mbr.sAMAccountname -ieq $_.sAMAccountname }
                }
            } else {
                Write-Host "AD-Gruppe '$groupname' nicht gefunden"
            }
        } else {
            # Weder inputfile noch groupname angegeben, daher alle Benutzer mit sAMAccountname -like "a*" - nur zu Testzwecken ...
            $u=$allUsers | Where-Object { $_.samaccountname -like "a*" } 
        }
    }

    $csvData=$u | foreach-object {
        $aktU=$_
        if ($aktU.extensionAttribute2) {
            $identity='cn='+($aktU.extensionAttribute2 -replace '\.us$','')+$identitySuffix
            [PSCustomObject]@{
                Operation=$operation
                UserDN=$identity
                RoleDN=$roleDN
                Comment=$Comment
            }
        }
    }
    if ($csvData) {
        # das CSV darf fuer den RoleImport-Treiber keinen Header haben, aber Export-CSV hat keinen Parameter den Header zu unterdruecken
        $csvData | ConvertTo-Csv -NoTypeInformation -Delimiter ';' | Select-Object -Skip 1 | Out-File -FilePath $resultfile -Encoding Ascii
    }
<#
} else {
    Write-Host "Rolle '$roleDN' - kein gueltiger distinguishedName!"
}
#>
