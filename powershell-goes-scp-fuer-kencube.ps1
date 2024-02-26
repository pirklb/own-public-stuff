# Equivalent fuer: m:\watchit\pscp.exe -scp -pw STRENGGEHEIMESKENNWORT m:\watchit\memload.vbs root@vmw01s:/tmp/memload.vbs
$pw="STRENGGEHEIMESKENNWORT"
$localPath = "m:\watchit\memload.vbs"
$remotePath = "/tmp/"

# schoener ist es, den sshHostKey mittels SshHostKeyFingerprint = "ssh-rsa 1024 abcdefghijklmnopqrstuvwxyz" mitzugeben (und dafuer GiveUpSecurity... nicht zu setzen)
$sessionOptions = New-Object WinSCP.SessionOptions -Property @{
    Protocol = [WinSCP.Protocol]::Scp
    HostName = "vmw01s.lkw-walter.com"
    UserName = "root"
    Password = "$pw"
    GiveUpSecurityAndAcceptAnySshHostKey = $true
} 

#so ist es schoener - und funktioniert auch (den sshkey kann man sich beim Aufruf vom grafischen winscp.exe und Verbindung mit dem Ziel in die Zwischenablage kopieren):
$sessionOptions = New-Object WinSCP.SessionOptions -Property @{
    Protocol = [WinSCP.Protocol]::Scp
    HostName = "vmw01s.lkw-walter.com"
    UserName = "root"
    Password = "$pw"
    SshHostKeyFingerprint = "ssh-rsa 2048 xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx"
}

$session = New-Object WinSCP.Session
$session.Open($sessionOptions)
$transferResult = $session.PutFiles($localPath, $remotePath)

$transferResult

Transfers                                                     Failures IsSuccess
---------                                                     -------- ---------
{\\lkw-walter.com\data\WND\Users$\Pirklb\WatchIT\memload.vbs} {}            True

