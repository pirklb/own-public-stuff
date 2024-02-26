param([Alias('c','csv','f','file')]$filename)
$Version='20.1215.1'

$c=import-csv -Path $filename -Delimiter ';' -Encoding 'UTF8'

#$zeilen=$s.Split([Environment]::NewLine)                                                                  
$zeilen=$c.Displayname
$zeilen | % {
   $z=$_
   $g=$null
   $g=Get-ADGroup -Filter { Displayname -eq $z }
   if (!$g) { $z }
}           
