#load text into $text
#1
$text = Get-Content .\test.txt -Raw 

#variable to array
#2
$array1 = $text.ToCharArray()

#reverse array
[array]::Reverse($array1)
#this will have literally reversed $array1
#without requiring a new array

#ALL CAPS CHARATERS IN $array1
#3
$array1.ToUpper()

#Convert $array1 to a string
[string]$array1




<#
0::Source material:

1:: https://stackoverflow.com/questions/7976646/powershell-store-entire-text-file-contents-in-variable

2:: https://devblogs.microsoft.com/scripting/reverse-strings-with-powershell/

3:: https://devblogs.microsoft.com/scripting/powertip-convert-to-upper-case-with-powershell/

#>
