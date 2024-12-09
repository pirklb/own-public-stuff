$Version='21.115.1'
# Version
#   21.115.1 ... erste Version
#   21.115.2 ... Triggers durch Trigger ersetzt (Zeile 8, 32)

#region Trigger
#mehrere Trigger definieren
$Trigger = @(
  $(New-ScheduledTaskTrigger -Weekly -WeeksInterval 1 -DaysOfWeek Monday,Tuesday,Wednesday,Thursday,Friday -At 1am),
  $(New-ScheduledTaskTrigger -Weekly -WeeksInterval 1 -DaysOfWeek Monday,Tuesday,Wednesday,Thursday,Friday -At 10am)
)

# Wiederholungstrigger
$Trigger = New-ScheduledTaskTrigger -Weekly -WeeksInterval 1 -DaysOfWeek Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday -At 1am -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Hours 20)
#endregion Trigger

#region Principal
# NT-AUTHORITY\SYSTEM als Task Principal
$PrincipalSYSTEM = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -Logontype ServiceAccount -RunLevel Highest

#endregion Principal

#region Task Action
$Action = New-ScheduledTaskAction -Execute "C:\Windows\system32\vssadmin.exe" -WorkingDirectory "%systemroot%\system32" -Argument "Create Shadow /AutoRetry=15 /For=\\?\Volume$ID\"
$ActionPSScript = New-ScheduledTaskAction -Execute "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -WorkingDirectory "%systemroot%\system32" -Argument "C:\Scriptpfad\Scriptname.ps1"
#endregion Task Action

$TaskName = 'Taskname'
$TaskPath = '\Beispiel'
$Settings = New-ScheduledTaskSettingsSet
$Principal = $PrincipalSYSTEM
$Action = $ActionPSScript
$Task = New-ScheduledTask -Action $Action -Principal $Principal -Settings $Settings -Trigger $Trigger
Register-ScheduledTask $TaskName -InputObject $Task -TaskPath $TaskPath

