param(
  [Parameter(Mandatory)][Alias('f','csv','csvfile')[string]$filename
)
$Version='20201120.1'

#region Modul lkw-Elasticsearch - Version 20.511.1
function Convert-CredentialToHeader {
  param(
    [Alias('c','cred')][PSCredential]$Credential = $null
  )

  if ($Credential) {
    $username = $Credential.Username
    $password = $Credential.GetNetworkCredential().Password
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username, $password)))
    $Header = @{ Authorization = ("Basic {0}" -f $base64AuthInfo) }
  } else {
    $Header = $null
  }

  return $Header
}

function Invoke-ElasticsearchREST {
  param(
    [Parameter(Mandatory = $true)][Alias('es','esurl')][string]$ElasticsearchURL,
    [ValidateSet('GET','POST','PUT','DELETE','HEAD')][Alias('m')][string]$method = 'GET',
    [Alias('b')][string]$body = $null,
    [Alias('c','cred')][PSCredential]$Credential = $null
  )

  $Header = Convert-CredentialToHeader -Credential $Credential

  $EV = $null
  if ($body) {
    $j2 = [System.Text.Encoding]::UTF8.getbytes($body)
    $r = Invoke-RestMethod -Method $method -Uri $ElasticSearchURL -Body $j2 -ContentType "application/json" -ErrorAction SilentlyContinue -ErrorVariable EV -Headers $Header
  } else {
    $r = Invoke-RestMethod -Method $method -Uri $ElasticSearchURL -ContentType "application/json" -ErrorAction SilentlyContinue -ErrorVariable EV -Headers $Header 
  }
  
  if (!$EV) {
    # OK
    return @{statusRestMethod='OK';statusRestMethodDetail='OK';result=$r}
  } else {
    return @{statusRestMethod='Error';statusRestMethodDetail=$EV.ErrorRecord.Exception.Message;result=$EV.ErrorRecord.Errordetails.Message}
  }
}

function DateTime2Elasticsearch
{
  param(
    [Parameter(Mandatory = $true, Position = 1)] [DateTime]$d,
    [Parameter(Mandatory = $false, Position = 2)] [string]$format = "yyyy-MM-ddTHH:mm:ss"
  )
  if ($format.toLower() -eq "epoch") {
    [long] ( ($d-$s).TotalMilliseconds )
  } else {
    Get-Date($d) -format $format
  }
}
#endregion

#region Modul lkw - Version 20.602.1
function Write-LKWLogDebug {
<#
.SYNOPSIS
Schreibt ein DebugFile.
.DESCRIPTION
Idealerweise gibt man am Anfang seines Script eine DebugFileName Variable an und übergibt der Funktion diese Variable als DebugFileName.
.PARAMETER DebugFileName
Pfad und Dateiname für das DebugFile.
.PARAMETER dbgText
Text fuer das DebugFile.
.PARAMETER neuesFile
Nicht notwendig. Default ist $false, der dbgText wird somit angehaengt. Bei $true wird ein neues File angelegt (das Alte ueberschrieben).
.EXAMPLE
 Write-LKWLogDebug "C:\Temp\DebugFile.txt" "DAS IST MEIN DEBUGTEXT"
.EXAMPLE
 Write-LKWLogDebug $DebugFileName "DAS IST MEIN DEBUGTEXT"
.EXAMPLE
 Write-LKWLogDebug $DebugFileName $DebugText
#>
	param(
		[Alias('f','dbgFile')][string]$DebugFileName,
		[Alias('t','text','debugtext')][string]$dbgText,
		[boolean]$neuesFile = $false
	)
	[string]$h = (Get-Date -format "yyyy.MM.dd HH:mm:ss.fff").tostring()
	[string]$HU = $env:USERNAME
	$dbgText = $h + " " + $HU + ": " + $dbgText
	if ($neuesFile)
	{
		$dbgText | Out-File $DebugFileName
		Write-Debug $dbgText
	}
	else
	{
		$dbgText | Out-File $DebugFileName -append
		Write-Debug $dbgText
	}
}

#endregion 
$DbgFile = 'C:\System\Sitzplan-Client.txt'
((Get-Date -Format 'yyyy.MM.dd HH:mm:ss.fff') + " ********* Start Auto!Sitzplanclient $Version *********") | Out-File -FilePath $DbgFile -Append
#region allgemeine Variablen
$esurl2 = 'https://sitzplan.ece.prod.lkw-walter.com:9243'
$secPWD=(ConvertTo-SecureString '6RM8MZODI6XjRXjPAdjw-prod' -AsPlainText -Force)
[PSCredential]$cred=New-Object System.Management.Automation.PSCredential ('svc_sitzplan',$secPWD)
$index = "sitzplan"
#endregion


#region Main Programm
$query='{
    "_source": {
        "excludes": ["current" ]
    },
    "sort": [
        { "timestamp" : {"order": "desc" } }
    ],
    "query": {
      "bool": {
        "must": {
          "match": {
            "type": "user2computer"
          }
        },
        "filter": {
          "range": {
            "timestamp": {
              "gte": "now-1d/d"
            }
          }
        }
      }
    },
    "size":10000
  }'

$result=Invoke-ElasticsearchREST -method POST -ElasticsearchURL ("$esurl2/$index/_search") -Credential $cred -body ($query)
if ($result.statusRestMethod -eq 'OK') {
    $hits=$result.result.hits.hits
    if ($hits) {
        $hits=$hits._source
        $hits | export-csv -Delimiter ';' -Path $filename -NoTypeInformation
    } else {
        Write-Host ('Keine Treffer gefunden')
    }
} else {
    Write-Host ("Fehler bei der Abfrage ($($result.statusRestMethod))")
}

