$inputFile = "input.txt"
$wordCount = 4

# Read words from the input file
$words = Get-Content $inputFile | Get-Random -Count $wordCount

# Combine the words into a single passphrase
$passphrase = ($words | ForEach-Object {$_}).Trim()

# Add a special character and a number to the passphrase
$specialCharacters = "!@#$%^&*"
$specialCharacter = $specialCharacters[(Get-Random -Maximum $specialCharacters.Length)]
$number = Get-Random -Minimum 100 -Maximum 999

# Output the final passphrase
Write-Host "$passphrase$specialCharacter$number"
