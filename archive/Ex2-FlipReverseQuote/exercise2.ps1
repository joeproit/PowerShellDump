#JoePro 9/25/22
$regex = '' #empty for looping
$tempfile = '_test2.txt' #tempfile
$outputfile = 'test2output.txt' #output

#read file line by line [1]
#output to temp file
Foreach($line in Get-Content .\test2.txt)
{
    if($line -match $regex){
        $caps = ($line.ToUpper()) #ALL CAPS
        $caps[-1..-$caps.Length] -join '' | Out-File -FilePath $tempfile -Append #reverse and write to file [2]
    }
    
}

#flip the line order in the $tempfile [3]
$rev = Get-Content $tempfile
Set-Content -Path $outputfile -Value ($rev[($rev.Length-1)..0])

#clean-up
Remove-Item $tempfile

<#
Source
1:: https://shellgeek.com/read-file-line-by-line-in-powershell/
2:: https://www.cloudnotes.io/revert-a-string-in-powershell/
3:: https://www.winhelponline.com/blog/flip-or-reverse-text-file-contents-windows/#powershell
#>
