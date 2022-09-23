# Exercise 1 result
<img src="https://github.com/joeproit/PowerShellDump/blob/main/Exercise1.png">

```powershell
<#
Task: write a PowerShell script that takes a Process Name, shows the Processes's Name, Command Line, and Process ID. Then asks for the Process ID and kills that process. 
Inputs: initially the Process Name, and then a Process ID 
Output: Process information, and the given Process ID is killed 
Note: PowerShell has many ways to accomplish this, use whatever method you like (eg. Function, Script, Pipeline, etc) 
Hint: It will be easier with PowerShell 7, but can be done with Windows PowerShell. 
 
#>

<# JoePro 09/22/22 
No error handling
Stop-Process will confirm, but attempt kill any PID you enter

More mature script would loop objects, validate input, error trap and log
#>

#Clean variables function
$Sstart=""
New-Variable -force -name Sstart -value ( Get-Variable | ForEach-Object { $_.Name } )
function MrCleanup {
  Get-Variable | 
  Where-Object { $Sstart -notcontains $_.Name } | ForEach-Object { Remove-Variable -Name "$($_.Name)" -Force -Scope "global" }

}

$processname = Read-Host -Prompt "Enter Process Name to search for...:"
Get-Process -Name $processname | Format-Table Id,Name

$killprocess = Read-Host -Prompt "Enter Process ID to kill...:"
Stop-Process -Id $killprocess -Force -Confirm 

#Clean-up
MrCleanup

#Bye
Exit 0
