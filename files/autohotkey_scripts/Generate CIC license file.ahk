#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

SimplePing(URL, byref speed, timeout = 1000)
{
  Runwait,%comspec% /c ping -w %timeout% %url%>ping.log,,hide
  fileread , StrTemp, ping.log
  filedelete, ping.log
  if RegExMatch(StrTemp, "Average = (\d+)", result)
    return result1
  else
    return "No response."
}

if SimplePing("licgenwebserv",speed,200) <> "No response."
{
  	Msgbox, Run "C:\ProgramData\PuppetLabs\puppet\etc\modules\cicserver\files\\licensing\LicGenClient\LicGenClient.exe -hostid %clipboard% -hostname %A_ComputerName% -version 4 -fulllic 1000"
	Run "C:\ProgramData\PuppetLabs\puppet\etc\modules\cicserver\files\\licensing\LicGenClient\LicGenClient.exe -hostid %clipboard% -hostname %A_ComputerName% -version 4 -fulllic 1000"
}
else
{
  Msgbox Can't reach license server (licgenwebserv)
}
