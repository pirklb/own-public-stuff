param(
    [Parameter(Mandatory=$true,Helpmessage="Personalnummer (fuenfstellig) die geloescht werden soll")][Alias('PNR','Personalnummer','Personalnr')][string]$persNr,
    [Parameter(Mandatory=$true,Helpmessage="PersonenId (MARefNr lt. Persis)")][Alias('PId','PersonenId','HRID')][string]$MARefId
)
$Version='22.701.1'
# 22.630.1 ... Erste Version
# 22.701.1 ... kleine Korrektur bei Personalservice,AnAb,SW2000

$befehle=@(
    [PSCustomObject]@{
        Applikation="Personalservice"
        Datenbank="MSSQL DBAG12"
        Statements=@("delete from [PERSISINTERFACE].[dbo].[IDM_PERSON_PERSONALNUMMER] where Personalnummer ='${persnr}'",
            "delete from [PERSISINTERFACE].[dbo].[IDM_PERSONALNUMMER_SIGNATUR] where Personalnummer ='${persnr}'",
            "delete from [PERSISINTERFACE].[dbo].[IDM_PERSONALNUMMER] where Personalnummer ='${persnr}'",
            "delete from [PERSISINTERFACE].[dbo].[IDM_PERSON] where PersonalnummerAktuell ='${persnr}' or PersonalnummerAktuellGeaendert ='${persnr}'",
            "delete from [PERSISINTERFACE].[dbo].[IDM_EVENTLOG] where table_key='PersonenId=${MARefId}' or table_key='Personalnummer=${persnr}'")
    },
    [PSCustomObject]@{
        Applikation="MATATOR"
        Datenbank="DB2/400"
        Statements=@("delete from perspublic.orgeinheit_mitarbeiter_taetigkeit where personalnummer='${persnr}';",
            "delete from perspublic.orgeinheit_mitarbeiter where personalnummer='${persnr}';",
            "delete from perspublic.mitarbeiter_abwesend where personalnummer='${persnr}';",
            "delete from perspublic.mitarbeiter_signatur where personalnummer='${persnr}';",
            "delete from perspublic.mitarbeiter_medien where personalnummer='${persnr}';",
            "delete from perspublic.mitarbeiter_verkehrsdirektion where personalnummer='${persnr}';",
            "delete from perspublic.mitarbeiter_vorgesetzte where personalnummer='${persnr}';",
            "delete from perspublic.mitarbeiter_vorgesetzter_orgeinheiten where personalnummer='${persnr}';",
            "delete from perspublic.mitarbeiter_operativer_mandant where personalnummer='${persnr}';",
            "delete from perspublic.mitarbeiter_verrechnungs_mandant where personalnummer='${persnr}';",
            "delete from perspublic.mitarbeiter_stammabteilung where personalnummer='${persnr}';",
            "delete from perspublic.mitarbeiter_mandant where personalnummer='${persnr}';",
            "delete from perspublic.mitarbeiter where personalnummer='${persnr}';",
            "delete from perspublic.mitarbeiter_zuteilung where personalnummer='${persnr}';",
            "delete from perspublic.gruppen_mitarbeiter where personalnummer='${persnr}';",
            "delete from perspublic.persis_daten where personalnummer='${persnr}';",
            "delete from perspublic.mitarbeiter_schnittstelle where personalnummer='${persnr}';")
    },
    [PSCustomObject]@{
        Applikation="AnAb"
        Datenbank="DB2/400"
        Statements=@("DELETE FROM Pers.MitarbeiterZeitmodell WHERE PERSNR IN ('${persnr}');",
            "DELETE FROM Pers.MitarbeiterAnAbDetail WHERE PERSNR IN ('${persnr}');",
            "DELETE FROM Pers.URLAUBBUCHUNG where persnr in ('${persnr}');",
            "DELETE FROM Pers.PRIVATZEITBUCHUNG where persnr in ('${persnr}');",
            "DELETE FROM Pers.Mitarbeiterstammstandort WHERE PERSNR in ('${persnr}');",
            "DELETE FROM Pers.MitarbeiterMandant WHERE PERSNR IN ('${persnr}');",
            "DELETE FROM Pers.MitarbeiterSignatur WHERE PERSNR IN ('${persnr}');",
            "DELETE FROM Pers.MitarbeiterStamm WHERE PERSNR IN ('${persnr}');")
    },
    [PSCustomObject]@{
        Applikation="PIS"
        Datenbank="MSSQL DBAG12"
        Statements=@("DELETE FROM [Pers].[Personal].[Stammdaten] where persnr like '%-${persnr}'")
    },
    [PSCustomObject]@{
        Applikation="Proposal"
        Datenbank="MSSQL DBAG12"
        Statements=@("DELETE FROM [Pers].[Personal].[ProMain] where persnr like '%-${persnr}'")
    },
    [PSCustomObject]@{
        Applikation="SW2000"
        Datenbank="DB2/400"
        Statements=@("DELETE FROM lkwgen.kog k WHERE EXISTS (SELECT * FROM lkwgen.pmi p WHERE (k.c4c2nb=p.qmc2nb) AND p.qmpenb ='${persnr}' AND p.qmc2nb<>0);",
            "DELETE FROM lkwsql.kmm k WHERE EXISTS (SELECT * FROM lkwgen.pmi p WHERE (k.kogkommunikationlaufnr=p.qmc2nb) AND p.qmpenb='${persnr}');",
            "DELETE FROM lkwgen.pmi WHERE qmpenb='${persnr}';")
    }
)

Write-Host "SQL-Statements generieren, Version $Version"
Write-Host "Die gruen geschriebenen Zeilen sind die eigentlichen Statements. Diese muessen im jeweiligen Datenbankclient ausgefuehrt werden"
foreach ($appl in $befehle) {
    Write-Host "Applikation: $($appl.Applikation)"
    Write-Host "Datenbank: $($appl.Datenbank)"
    foreach ($statement in $appl.Statements) {
        Write-Host $statement -foregroundcolor green
    }
    Write-Host "-----------------------------------------------------------------------------------"
}