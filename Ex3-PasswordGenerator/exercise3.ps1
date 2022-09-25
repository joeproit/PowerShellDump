<# Net System.web is not available in PS Core
 # Figuring different method

Add-Type -AssemblyName System.Web
[System.Web.Security.Membership]::GeneratePassword(16,2)


##USAGE:
PS> GenPass 22
System.Security.SecureString
akB+JeqYgvv=raWGLx2+6FR

#>

function GenPass {
param(  [ValidateRange(16, 256)]
        [int]
        $len = 22
    )

do {
    $pass = -join (0..$len | ForEach-Object { $list | Get-Random })
    $spechars = '@#$%^&*-()+='.ToCharArray() #no pipe, brackets, punctuation or slashes
    $regchars = 'A'..'N' + 'P'..'Z' + 'a'..'k' + 'm'..'z' #No cap O or lower-case L 
    $numchars = '0'..'9' # no zero
    $list = $regchars + $numchars + $spechars #full character list
    [int]$lowercheck = $pass -cmatch '[a-z]' #match lowercase
    [int]$uppercheck = $pass -cmatch '[A-Z]' #match uppercase
    [int]$digitcheck = $pass -match '[0-9]' #match digits
    [int]$specialcheck = $pass.IndexofAny($spechars) -ne -1 #match special characters array
}
until (($lowercheck + $uppercheck + $digitcheck + $specialcheck) -ge 3) #until 3 or more per are generated

$pass | ConvertTo-SecureString -AsPlainText 
$pass

}

# Help from:
# https://dev.to/onlyann/user-password-generation-in-powershell-core-1g91