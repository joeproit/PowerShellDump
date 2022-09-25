<# JoePro 09/22/22 
No error handling
Stop-Process will confirm, but attempt kill any PID you enter
#>

$processname = Read-Host -Prompt "Enter Process Name to search for...:"
Get-Process -Name $processname | Format-Table Id,Name

$killprocess = Read-Host -Prompt "Enter Process ID to kill...:"
Stop-Process -Id $killprocess -Force -Confirm 

