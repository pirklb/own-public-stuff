$version='24.807.1'
# 24.807.1 ... Query für Mitarbeiter angepasst
# 24.729.1 ... invoke-IdmRest um infoJavascript erweitert (damit man das ausgeben kann, was bei der Javascript Funktion als allKey angegeben werden muss)
# 24.618.1 ... Initialversion des Seeds

# https://idm.lkw-walter.com/osp/a/idm/auth/oauth2/.well-known/openid-configuration - interessante Infos

#region Idm
# 22.304.2
#region Idm Config Values
$config=@{}
function set-IdmInfos {
    param(
        [string]$server,
        [string]$BaseUrl,
        [string]$clientid,
        [string]$clientsecret,
        [string]$username,
        [string]$password,
        [string]$refreshToken,
        [string]$accessToken,
        [string]$token_endpoint,
        [string]$authorization_endpoint,
        [string]$end_session_endpoint
    )
    $ok=$false
    if ($PSBoundParameters.keys -icontains 'server') { $ok=$true;$config.server=$server;$config.BaseUrl="https://$server/" }
    if ($PSBoundParameters.keys -icontains 'BaseUrl') { $ok=$true;$config.BaseUrl=$BaseUrl }
    if ($PSBoundParameters.keys -icontains 'clientId') { $ok=$true;$config.clientId=$clientId }
    if ($PSBoundParameters.keys -icontains 'clientsecret') { $ok=$true;$config.clientSecret=$clientSecret }
    if ($PSBoundParameters.keys -icontains 'username') { $ok=$true;$config.username=$username }
    if ($PSBoundParameters.keys -icontains 'password') { $ok=$true;$config.password=$password }
    if ($PSBoundParameters.keys -icontains 'refreshToken') { $ok=$true;$config.refreshToken=$refreshToken }
    if ($PSBoundParameters.keys -icontains 'accessToken') { $ok=$true;$config.accessToken=$accessToken }
    if ($PSBoundParameters.keys -icontains 'token_endpoint') { $ok=$true;$config.token_endpoint=$token_endpoint }
    if ($PSBoundParameters.keys -icontains 'authorization_endpoint') { $ok=$true;$config.authorization_endpoint=$authorization_endpoint }
    if ($PSBoundParameters.keys -icontains 'end_session_endpoint') { $ok=$true;$config.end_session_endpoint=$end_session_endpoint }

    if (!$ok) {
        Write-Error -Message "kein richtiger Parameter uebergeben" -Category InvalidArgument
    }
}

function get-IdmInfo {
    param(
        [Parameter(Mandatory)][ValidateSet('server','baseurl','clientid','clientsecret','username','password','refreshtoken','accesstoken','token_endpoint','authorization_endpoint','end_session_endpoint')]$info
    )
    if ($info -ieq 'server') { $config.server }
    if ($info -ieq 'baseUrl') { $config.BaseUrl }
    if ($info -ieq 'clientid') { $config.clientId }
    if ($info -ieq 'clientsecret') { $config.clientsecret }
    if ($info -ieq 'username') { $config.username }
    if ($info -ieq 'password') { $config.password }
    if ($info -ieq 'refreshToken') { $config.refreshToken }
    if ($info -ieq 'accessToken') { $config.accessToken }
    if ($info -ieq 'token_endpoint') { $config.token_endpoint }
    if ($info -ieq 'authorization_endpoint') { $config.authorization_endpoint }
    if ($info -ieq 'end_session_endpoint') { $config.end_session_endpoint }
}

#endregion Idm Config Values
#region Idm Basis-Funktionen
function Initialize-Idm {
if ($PSVersionTable.PSEdition -eq 'Core') {
	$Script:PSDefaultParameterValues = @{
        "invoke-restmethod:SkipCertificateCheck" = $true
        "invoke-webrequest:SkipCertificateCheck" = $true
	} }  else {    Add-Type -AssemblyName System.Web
    if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type)
    {
		$certCallback = @"
			using System;
			using System.Net;
			using System.Net.Security;
			using System.Security.Cryptography.X509Certificates;
			public class ServerCertificateValidationCallback
			{
				public static void Ignore()
				{
					if(ServicePointManager.ServerCertificateValidationCallback ==null)
					{
						ServicePointManager.ServerCertificateValidationCallback += 
							delegate
							(
								Object obj, 
								X509Certificate certificate, 
								X509Chain chain, 
								SslPolicyErrors errors
							)
							{
								return true;
							};
					}
				}
			}
"@
		Add-Type $certCallback
	}
	[ServerCertificateValidationCallback]::Ignore()
}
    $server='idm.lkw-walter.com'
    set-IdmInfos -server $server `
      -clientid 'rbpmrest' `
      -clientSecret ([System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('Tm54RDF4UmU0M0RsWGtuQlk5RmE='))) `
      -token_endpoint "https://$server/osp/a/idm/auth/oauth2/token" `
      -authorization_endpoint "https://$server/osp/a/idm/auth/oauth2/auth"  `
      -end_session_endpoint "https://$server/osp/a/idm/auth/oauth2/logout"  
}

function Invoke-IdmLogin {
    Param(
        [Parameter(Mandatory,HelpMessage='IDM-Username als distinguishedName')][string]$username,
        [Parameter(Mandatory)][string]$PW
    )
    $server=get-IdmInfo 'server'
    $BaseURL=get-IdmInfo 'BaseUrl'
    $atUrl=get-IdmInfo 'token_endpoint'
    $clientId=get-IdmInfo 'clientId'
    $clientSecret=get-IdmInfo 'clientSecret'
    
    $auth="${clientid}:${clientsecret}"
    $arr=[char[]]$auth
    $b64auth=[Convert]::ToBase64String($arr)
    $authheader="Basic $b64auth"
    $uEnc=[System.Web.HttpUtility]::UrlEncode($username)
    $pEnc=[System.Web.HttpUtility]::UrlEncode($PW)

    $headers = @{"Authorization"=$authheader;"Content-Type"="application/x-www-form-urlencoded"}
    $body="grant_type=password&username=$uEnc&password=$pEnc"

    try {
      $response = (Invoke-WebRequest $aturl -Method 'POST' -Headers $headers -Body $body -ErrorVariable EV -UseBasicParsing).Content | ConvertFrom-Json
      @{
          accessToken=$response.access_token
          refreshToken=$response.refresh_token
      }
      set-IdmInfos -accessToken $response.access_Token -refreshToken $response.refresh_token 
    } catch {
        $statuscode = $EV.errorrecord.Exception.Response.StatusCode
        $statusMessage = $EV.errorrecord.Exception.Response.StatusDescription 
        if ($statusCode -eq 400) {
          Write-Error("Falsche Anmeldedaten '${statuscode}:${statusmessage}'") 
        } else {
          Write-Error("Unerwarteter Fehler '${statuscode}:${statusmessage}'") 
        }
        $response=$null
        $false
    }
}

function Invoke-IdmLogout {
    Param(
        [string]$refreshToken=''
    )
    $server=get-IdmInfo 'server'
    $BaseURL=get-IdmInfo 'BaseUrl'
#    $atUrl=get-IdmInfo 'token_endpoint'
    $clientId=get-IdmInfo 'clientId'
    $clientSecret=get-IdmInfo 'clientSecret'
    if (!$refreshToken) {
        $refreshToken=get-IdmInfo 'refreshToken'
    }
    $auth="${clientid}:${clientsecret}"
    $arr=[char[]]$auth
    $b64auth=[Convert]::ToBase64String($arr)
    $authheader="Basic $b64auth"

    $revokeUrl="${BaseURL}osp/a/IDM/auth/oauth2/revoke"
    $headers = @{"Authorization"=$authheader;"Content-Type"="application/x-www-form-urlencoded"}
    $body="token_type_hint=refresh_token&token=$refreshToken"

    try {
        $response = (Invoke-WebRequest $revokeUrl -Method 'POST' -Headers $headers -Body $body -ErrorVariable EV -UseBasicParsing).StatusCode 
        if ($response -eq 200) {
            set-IdmInfos -accessToken $null -refreshToken $null
        } else {
            throw "Logoff failed ($response)"
        }     
        Write-Host ("revoke token ... Response='$response'")
    } catch {
        if ($EV) {
            $statuscode = $EV.errorrecord.Exception.Response.StatusCode
            $statusMessage = $EV.errorrecord.Exception.Response.StatusDescription 
            Write-Error("Unerwarteter Fehler '${statuscode}:${statusmessage}'") 
        } else {
            $statuscode = $_.CategoryInfo.TargetName -replace '.*\(','' -replace '\)',''  # macht aus "blab bla (300)" "300"
            Write-Error ("Unerwarteter Statuscode ($statuscode)")
        }
        $response=$null
        $false
    }
}

function Use-RefreshToken {
    $clientId=get-IdmInfo -info 'clientid'
    $clientsecret=get-IdmInfo -info 'clientsecret'
    $te=get-IdmInfo -info 'token_endpoint'
    $rt=get-IdmInfo -info 'refreshToken'

    $auth="${clientid}:${clientsecret}"
    $arr=[char[]]$auth
    $b64auth=[Convert]::ToBase64String($arr)
    $authheader="Basic $b64auth"

    $headers = @{"Authorization"=$authheader;"Content-Type"="application/x-www-form-urlencoded"}
    $body="grant_type=refresh_token&refresh_token=$rt"
    $response=Invoke-RestMethod -Uri $te -Method 'POST' -headers $headers -Body $body
    $response.access_token
    set-IdmInfos -accessToken ($response.access_token)
}

function Invoke-IdmRest {
    Param(
        [Alias('requestUrl')][string]$ru=$requestUrl,
        [Alias('m')][string]$method='GET',
        [Alias('body')]$b,
        [Alias('headers')]$h,
        [switch]$all, # liefert alle Elemente (dazu muss der zugrundeliegende Request nextIndex unterstuetzen)
        [switch]$infoJavascript # wenn angegeben, wird der Propname, der beim Javascript angegeben werden muss, gelb angezeigt
    )
    if (!($ru -match '^https?://.*')) {
        $ru=(get-IdmInfo -info 'BaseUrl')+$ru
    }
    if (!$h) { $h=@{} }
    if (!($h.'Content-Type')) { $h.'Content-Type'='application/json; charset=utf-8' }
    $IRParams=@{
        Uri=$ru
        Method=$method
        Headers=$h
    }
    if ($method -ine 'get') {
        if ($b) {
            $IRParams.Body=$b
        }
    }
    $accToken=Use-RefreshToken
    $IRParams.Headers.Authorization="Bearer $accToken"
    Write-Debug ("Uri=$($IRParams.Uri)")
    Write-Debug ("Headers.Authorization=$($IRParams.Headers.Authorization)")
    try {
        $rContent = (Invoke-WebRequest @IRParams -ErrorVariable EV -UseBasicParsing).Content 
        $response = [System.Text.Encoding]::UTF8.GetString([System.Text.Encoding]::Default.GetBytes($rContent)) | ConvertFrom-Json
    } catch {
        $statuscode = $EV.errorrecord.Exception.Response.StatusCode
        $statusMessage = $EV.errorrecord.Exception.Response.StatusDescription 
        Write-Error("Unerwartete Exception '${statuscode}:${statusmessage}'")
        $response=$null
    }
    if ($response) {
        $propname=@(($response | Select-Object -ExcludeProperty nextIndex,arraySize -Property *) | Get-Member -MemberType NoteProperty)
        if ($propname.count -eq 1 ) {
            $propname=$propname[0].Name
        } else {
            $propname=@($propname | Where-Object { $_.Definition -like '*`[`]'})[0].Name
        }
        $erg=$response."$propname"
        if ($infoJavascript) {
            write-host "allKey fuer Javascript='$propname'" -ForegroundColor DarkYellow
        }

        if ($all) {
            Write-Debug("erster nextIndex=$($response.nextIndex)")
            while ($response.nextIndex -and ($response.nextIndex -gt 0)) { # manchmal ist nextIndex 0, wenn es keine weiteren Infos gibt, manchmal -1
                $t=$IRParams.Clone()
                $t.Uri=($t.Uri+"&nextIndex="+$response.nextIndex)
                Write-Debug("nextIndex=$($response.nextIndex)")
                try {
                    $rContent=(Invoke-WebRequest @t -ErrorAction Stop -ErrorVariable EV -UseBasicParsing).Content 
                    $response = [System.Text.Encoding]::UTF8.GetString([System.Text.Encoding]::Default.GetBytes($rContent)) | ConvertFrom-Json
                    $erg+=$response."$propname"
                } catch {
                    $statuscode = $EV.errorrecord.Exception.Response.StatusCode
                    if ($statuscode -ieq 401) {
                        Write-Debug "401 - AccessToken erneuern"
                        $accToken=Use-RefreshToken
                        $IRParams.Headers.Authorization="Bearer $accToken"
                    }                        
                }
            }
        }
        $erg
    } else {
        $null
    }
}
#endregion Idm Basis-Funktionen
#region Idm Spezielle Funktionen (weitere Kapselung von oefter gebrauchten REST-Calls)
function Add-IdmRoleMember {
    param(
        [Parameter(Mandatory)][string]$rolleId,
        [Parameter(Mandatory)][string]$memberId,
        [Parameter(Mandatory)][string]$reason
    )

    $Body=@{
        reason=$reason
        assignments=@{
            id=$rolleId
            assignmentToList=@{
                assignedToDn=$memberId
                subtype="user"
            }
            effectiveDate=""
            exipryDate=""
        }
    }
    $jBody=$Body | ConvertTo-Json -Compress
    try {
        Invoke-IdmRest -requestURL 'IDMProv/rest/catalog/roles/role/assignments/assign' -body $jBody -method POST
    } catch {
        Write-Error -Message "Assign Member ('$memberid') to Role ('$rolleid') failed" -Category InvalidResult
    }
}

function Remove-IdmRoleMember {
    param(
        [Parameter(Mandatory)][string]$rolleId,
        [Parameter(Mandatory)][string]$memberId,
        [Parameter(Mandatory)][string]$reason
    )

    $Body=@{
        reason=$reason
        assignments=@{
            id=$rolleId
            entityType="role"
            assignmentToList=@{
                assignedToDn=$memberId
                subtype="user"
            }
        }
    }
    $jBody=$Body | ConvertTo-Json -Compress
    try {
        Invoke-IdmRest -requestURL 'IDMProv/rest/access/assignments/list' -body $jBody -method DELETE
    } catch {
        Write-Error -Message "Remove Member ('$memberid') from Role ('$rolleid') failed" -Category InvalidResult
    }
}

function Get-RoleMember {
    param(
        [string]$roleId
    )

    $abody=@{dn=$roleId}
    $jabody=$abody | Convertto-Json -Compress

    $ass=Invoke-IdmRest -requestUrl "IDMProv/rest/catalog/roles/role/assignments/v2?nextIndex=1&q=&sortOrder=asc&sortBy=name&size=500" -body $jabody -method 'POST' -all
	@($ass) 
}
#endregion Idm Spezielle Funktionen (weitere Kapselung von oefter gebrauchten REST-Calls)
#endregion Idm

Initialize-Idm

Invoke-IdmLogin -username 'cn=rest-reader,ou=sa,o=idvault' -PW 'F#14Tz4V!UipWICWObf'

$folder="c:/temp/2024q3"
#$folder="/home/cont_path"

# Alle "IT"-Rollen - geht nicht für den rest-reader
#$ro=Invoke-IdmRest -requestUrl "IDMProv/rest/catalog/roles?q=IT_*" -all

# Filtern auf owner managed
#$omro=$ro | where { $_.categories.id -contains 'owner-managed' }


write-host ("Owner managed Rollen auslesen ...")
$omro=Invoke-IdmRest -requestUrl 'IDMProv/rest/catalog/roles/listV2?categoryKeys=owner-managed&size=1000' -infoJavascript # wenn man auf size=4000 geht, geht es auf einmal, d. h. rund eine Minute Laufzeit


write-host ("Owner der Owner managed Rollen ermitteln")

$omro | Foreach-Object {
  $aktRole=$_

  $body=@{
    roles=@{
      id=$aktRole.id
    }
  }
  $jBody=$body | ConvertTo-Json -Compress
  $roleDetails=invoke-idmrest -ru 'IDMProv/rest/catalog/roles/roleV2' -method POST -body $jbody
   $aktrole | Add-Member -Name 'owners' -Value ($roleDetails.owners.id) -MemberType NoteProperty
}

# Export als JSON
$omro | ConvertTo-Json -Depth 10 | Out-File -path "$folder/idm-owner-mgmt-roles.json" -Force

# Mitarbeiter-Identitäten
Write-Host ("Mitarbeiter Stammdaten auslesen")
#$ma=Invoke-IdmRest -requestUrl 'IDMProv/rest/access/users/list?q=*&clientId=1&size=1000&sortOrder=asc&sortBy=LastName&searchAttr=LastName,FirstName,Email,cN,workforceID,DirXML-NTAccountName&columnCustomization=true&filter=LastName,FirstName,Email,cN,workforceID,TelephoneNumber,DirXML-NTAccountname,itdidmHRID,itdprovLocation,itdprovCompany&advSearch=cN:p_*' -all -infoJavascript
$ma=Invoke-IdmRest -requestUrl 'IDMProv/rest/access/users/list?clientId=1&size=1000&advSearch=cN:p_*&columnCustomization=true&filter=LastName,FirstName,Email,cN,workforceID,TelephoneNumber,DirXML-NTAccountname,itdidmHRID,itdprovLocation,itdprovCompany' -all


$ma | ConvertTo-Json -Depth 10 | Out-File -path "$folder\idm-all-mas.json"
