$fn = 'C:\temp\2025q1\r10-16.json'
$j = get-content $fn | ConvertFrom-Json

# Resourcen (.res.resources[])
# (id) - technische Id der Resource
# name - Name der Resource (ACHTUNG: Bei AD-Gruppen ADS-INT_Group)
# (description) - description (der Ressource)
# mappingDescription - Beschreibung der Resourcenzuweisung zur Rolle
# entitlementValues.value - Detail des Entitlements (bei AD-Gruppen der Gruppenname)

# Parent Roles (.parent.roles[])
# (id) - technische Id der Parent Role
# name - Name der Parent Role
# (roleLevel.level) - Rollenebene
# (requestDescription) - Beschreibung der Anforderung

# Direkte Zuweisungen (vermutlich der Request, nicht die Zuweisung selbst)
# (dn) - id der Rolle
# recipientType - USER, GROUP, CONTAINER (OU)
# recipientDn - id des Empfängers
# (effectiveDate) - Gültigkeitsbeginn
# (expiryDate) - Gültigkeitsende
# (statusCode) - Statuscode der Zuweisung
# statusDisplay - Statustext der Zuweisung (z. b. "Completed")
# grant - Zuweisung (True), Entzug (False)


$infos = $j | ForEach-Object {
    $role = $_
    @{
        roleId            = $role.id -replace '^cn=', '' -replace ',cn=.*$', ''
        resources         = $role.res.resources | ForEach-Object {
            $res = $_
            [PSCustomObject]@{
                ressourcename       = $res.Name
                entitlement         = $res.entitlementValues.value
                resourceDescription = $res.description -replace ("`n", '<newline>')
                mappingDescription  = $res.mappingDescription -replace ("`n", '<newline>')
            }
        }
        parentRoles       = $role.parents.roles | ForEach-Object {
            $parent = $_
            [PSCustomObject]@{
                parentRoleName     = $parent.name
                roleLevel          = $parent.roleLevel.level
                requestDescription = $parent.requestDescription -replace ("`n", '<newline>')
            }
        }
        directAssignments = $role.assignments.assignmentStatusList | ForEach-Object {
            $da = $_
            [PSCustomObject]@{
                recipientType = $da.recipientType
                recipientDn   = $da.recipientDn
                effectiveDate = $da.effectiveDate
                expiryDate    = $da.expiryDate
                statusCode    = $da.statusCode
                statusDisplay = $da.statusDisplay
                grant         = $da.grant
            }
        }
    }
}

$alles = $infos | foreach-object {
    $aktInfo = $_
    $roleId = $aktInfo.roleId
    $aktInfo.resources | foreach-object {
        $aktRes = $_
        $resourcename = $aktRes.ressourcename
        $entitlement = $aktRes.entitlement
        $resourceDescription = $aktRes.resourceDescription
        $mappingDescription = $aktRes.mappingDescription
        $aktInfo.parentRoles | foreach-object {
            $aktParent = $_
            $parentRoleName = $aktParent.parentRoleName
            $roleLevel = $aktParent.roleLevel
            $requestDescription = $aktParent.requestDescription
            [PSCustomObject]@{
                roleId              = $roleId
                resourcename        = $resourcename
                entitlement         = $entitlement
                resourceDescription = $resourceDescription
                mappingDescription  = $mappingDescription
                parentRoleName      = $parentRoleName
                parentRoleLevel     = $roleLevel
                requestDescription  = $requestDescription
            }
        }
    }
}

$alles | Export-Csv -path c:\temp\2025q1\r10-final.csv -NoTypeInformation -Delimiter ';' -Encoding UTF8

