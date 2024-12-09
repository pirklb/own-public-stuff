$Version='20.1203.1'
# 20.1202.2 - Erweiterung um Containex D04 (AD-Gruppe 'dl_ctx_division_eng')
# 20.1203.1 - Korrekturen beim Setzen der Limits (davor hat es bei Klasse D immer einen Fehler geworfen)
function set-LimitKlasseD {
    <#
    .SYNOPSIS
    Berechnet das WARNING, und RECEIVE-Limit (in MB) fuer ein gegebenes Sendelimit (in MB) fuer die Mailboxklasse D.
    Die Rueckgabe hat zwei Eigenschaften
    - WARN
    - RECEIVE
    .DESCRIPTION 
    Berechnet das WARNING, und RECEIVE-Limit (in MB) fuer ein gegebenes Sendelimit (in MB) fuer die Mailboxklasse D.
    Die Rueckgabe hat zwei Eigenschaften
    - WARN
    - RECEIVE
    .PARAMETER SendeLimit
    Das SendeLimit in MB, fuer das die beiden Limits berechnet werden sollen
    .EXAMPLE
    set-LimitKlasseD -SendeLimit 1200
    Liefert die Limits WARNING und RECEIVE fuer ein SendeLimit von 1200 MB
    #>
    [CmdletBinding()]

    param (
        [Parameter(Mandatory=$True,ValueFromPipeline=$True)][Alias('Limit','SendLimit')][string]$SendeLimit
    )

    $erg=New-Object -TypeName PSObject -Property @{
        WARN=[int](0.9*$SendeLimit);
        RECEIVE=[int](2*$SendeLimit)
    }
    
    $erg
}

Import-Module ActiveDirectory
$DProz=25 # Steigerung von D (dann auf 100 MB runden)
$CaufD=1800 # sLimit einer Mailbox, die davor in Klasse C war 
$MXSVersion='MXS2016'
$Limit = @{ 
  MXS2010 = @{ 
    A=@{WARN=325;SEND=375;RECEIVE=1200}; 
    B=@{WARN=600;SEND=650;RECEIVE=1500}; 
    C=@{WARN=940;SEND=1000;RECEIVE=2200} 
    }; 
    MXS2016 = @{ 
    A=@{WARN=450;SEND=525;RECEIVE=1680}; 
    B=@{WARN=840;SEND=910;RECEIVE=2100}; 
    C=@{WARN=1310;SEND=1400;RECEIVE=3080}
    }
}

$namen=@('LW_VDI_WND_VDA2','LW_VDI_KUF_VD04','LW_VDI_KUF_VD07','dl_ctx_division_eng')
$g=$namen | % { get-adgroup $_ }
$gm=$g | % { Get-ADGroupMember -Identity $_ }
$users=$gm | % {
    get-aduser ($_.distinguishedName) -Properties givenname,surname,sAMAccountname,msExchExtensionAttribute27,msExchExtensionAttribute28
}

$users | % {
    $aktUser=$_
    $oriKlasse=$aktUser.msExchExtensionAttribute27
    $tempRaise=$aktUser.msExchExtensionAttribute28
    if ($oriKlasse -like 'D;*') {
        $sLimit=[int]($oriKlasse -replace("D;",""))*(100+$DProz)/100
        $sLimit=100*[math]::Round($sLimit/100)
        $Klasse="D;$sLimit"
        $wLimit=(set-LimitKlasseD -SendeLimit $sLimit).WARN
        $rLimit=(set-LimitKlasseD -SendeLimit $sLimit).RECEIVE
    }
    if ($oriKlasse -ieq 'C') {
        $Klasse="D;$CaufD"
        $sLimit=$CaufD
        $wLimit=(set-LimitKlasseD -SendeLimit $sLimit).WARN
        $rLimit=(set-LimitKlasseD -SendeLimit $sLimit).RECEIVE
    }
    if ($oriKlasse -ieq 'B') {
        $Klasse='C'
        $wLimit=$Limit.$MXSVersion.$Klasse.WARN
        $sLimit=$Limit.$MXSVersion.$Klasse.SEND
        $rLimit=$Limit.$MXSVersion.$Klasse.RECEIVE
    }
    if ($oriKlasse -ieq 'A') {
        $Klasse='B'
        $wLimit=$Limit.$MXSVersion.$Klasse.WARN
        $sLimit=$Limit.$MXSVersion.$Klasse.SEND
        $rLimit=$Limit.$MXSVersion.$Klasse.RECEIVE
    }
    
    "Benutzer '$($aktUser.sAMAccountname)', aktuelle Klasse '$oriKlasse', (temp. Erhoehung?: '$tempRaise'): neue Klasse '$Klasse' - WARN:$wLimit,SEND:$sLimit,RECEIVE:$rLimit"
    get-aduser ($aktUser.DistinguishedName) | set-ADUser -replace @{msExchExtensionAttribute27=$Klasse}
    if (!$tempRaise) {
        "    mDBStorageQuota=$(1024*$wLimit),mDBOverQuotaLimit=$(1024*$sLimit),mDBOverHardQuotaLimit=$(1024*$rLimit)"
        get-aduser ($aktUser.DistinguishedName) | set-ADUser -replace @{mDBUseDefaults=$false;mDBStorageQuota=[int](1024*$wLimit);mDBOverQuotaLimit=[int](1024*$sLimit);mDBOverHardQuotaLimit=[int](1024*$rLimit)}
    }
}