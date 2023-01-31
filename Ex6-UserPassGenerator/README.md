```PowerShell
$users = Import-Csv -Path "path_to_user_details.csv"

$output = @()

foreach ($user in $users) {
  $username = $user.FirstName[0] + $user.LastName
  $email = $username + "@example.com"
  $password = [System.Web.Security.Membership]::GeneratePassword(8,2)
  
  $output += [PSCustomObject]@{
    "Username" = $username
    "Email" = $email
    "Password" = $password
  }
}

$output | Export-Csv -Path "output.csv" -NoTypeInformation
```
