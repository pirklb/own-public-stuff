$Version='22.708.1'
# 22.708.1 - Initiale Version

# aehnliche Klartexte ergeben aehnliche gehashte Werte (von einem "echten" Hash verlangt man eigentlich, dass sich aehnliche Werte stark unterscheiden)
# Gross/Kleinschreibung wird im Klartext beachtet, d. h. ABC liefert ein anderes Ergebnis wie abc
# wie wahrscheinlich gleiche Ergebnisse bei unterschiedlichen Klartexten sind muss noch geprueft werden
# eventuell das Ergebnis fuer alle aktuellen AD-Benutzernamen ermitteln und schauen, ob man welche findet, die sich nur in einem Zeichen unterscheiden ...
function getPruefzeichen {
    Param(
        [string]$s
    )
    $basis='ABCDEFGHJKLMNPQRSTUVWXYZ0123456789' # die erlaubten Zeichen I und O wÃ¼rde ich verbieten, weil Verwechslung mit 1 und 0
    $wert=0
    for($i=0;$i -lt $s.length;$i++) { 
        $wert=$wert+($i+$basis.indexof($s[$i])) # es wird die Stelle im generierten Namen + Position des jeweiligen Zeichens in der Basis zusammengezaehlt
    }  
    $pruefzeichen=$basis[$wert % ($basis.length)] # diese Pruefsumme wird Module Laenge der Basis gerechnet und das soundsovielte Zeichen aus der Basis genommen
    $pruefzeichen
}
function generateHash{
    Param(
        [string]$s,
        [switch]$slow
    )
    $basis='ABCDEFGHJKLMNPQRSTUVWXYZ0123456789' # die erlaubten Zeichen I und O wÃ¼rde ich verbieten, weil Verwechslung mit 1 und 0, ev y und z auch verbieten - englische Tastatur, dann waeren es 32 Zeichen (2^5)

    Write-Host "'$s', Laenge ist: $($s.length), `$$s.length % 2=($($s.length % 2))"
    if ($s.length -gt 10) {
        while ($s.length -gt 10) {
            Write-Host "Vodoo ..."
            $e=''
            for ($i=0;$i -lt [int]($s.length / 2);$i++) {
            $x1=[byte]([char]($s[$i]))
            $x2=[byte]([char]($s[-($i+1)]))
            $xo=$x1 -bxor $x2
            $p=$basis[$xo % ($basis.length)]
            if ($slow) {
                Write-Host "($x1 -bxor $x2 = $xo) --> $p"
            }
            $e=$e+$p
            }
            if ($s.length %2 -eq 1) {
            $c=$s[$i++]
            $x1=[byte]([char]($c))
            $p=$basis[$x1 % ($basis.length)]
            if ($slow) {
                Write-Host ">> $c ($x1) = $p <<"
            }
            $e=$e+$p
            }
            Write-Host("Zwischenergebnis: $e, Laenge=$($e.length)")
            $s=$e
            if ($slow) {
                read-host "Warten nach Durchlauf ..."
            } 
        }
    } else {
        $e=""
        for($i=0;$i -lt $s.length;$i++) {
            $c=$s[$i]
            $x1=[byte]([char]($c))
            $p=$basis[$x1 % ($basis.length)]
            $e=$e+$p
        }
    }
    Write-Host "finales Ergebnis (vor Pruefsumme): '$e', Laenge=$($e.length)"
    $e
}

function get-hashedName {
    param(
        [string]$cleartextname
    )
    $gen = generateHash -s $cleartextname
    $pz = getPruefzeichen -s $gen
    $ergebnis = $gen + $pz
    $ergebnis
}

$s='abc1def2geh3ijk4lmn5opq6rst7e'
$gen=generateHash -s $s
$pz=getPruefzeichen -s $gen
$ergebnis=$gen+$pz
Write-Host ("'$s' ergibt den Hash '$gen', das ergibt das Pruefzeichen '$pz', das ergibt den vollen Namen: '$ergebnis'")
