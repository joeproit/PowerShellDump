# Import the Active Directory module
Import-Module ActiveDirectory

# Define the path to the user.csv and group.csv files
$userCsvPath = "C:\user.csv"
$groupCsvPath = "C:\group.csv"

# Define the target OU in Active Directory
$targetOU = "OU=Company,DC=domain,DC=com"

# Read the user details from the CSV file
$users = Import-Csv -Path $userCsvPath

# Create groups in Active Directory from the group CSV file
$groups = Import-Csv -Path $groupCsvPath

foreach ($group in $groups) {
    $groupName = $group.Name
    $groupDescription = $group.Description

    # Check if the group already exists, if not create it
    if (-not (Get-ADGroup -Filter { Name -eq $groupName })) {
        New-ADGroup -Name $groupName -Description $groupDescription -GroupCategory Security -GroupScope Global -Path $targetOU
        Write-Host "Group $groupName created."
    }
}

# Create users in Active Directory and add them to the matching groups
$results = foreach ($user in $users) {
    $firstName = $user.FirstName
    $lastName = $user.LastName
    $phone = $user.Phone
    $city = $user.City
    $state = $user.State
    $country = $user.Country

    # Generate username, email, and password based on the specified formats
    $username = ($firstName.Substring(0, 1) + $lastName).ToLower()
    $email = ($firstName.ToLower() + "." + $lastName.ToLower() + "@company.com")
    $password = ($firstName.Substring(0, 1).ToUpper() + $lastName.Substring(0, 1).ToLower() + "#" + "2023")

    # Create the user in Active Directory
    $userParams = @{
        SamAccountName = $username
        GivenName = $firstName
        Surname = $lastName
        UserPrincipalName = $email
        Name = "$firstName $lastName"
        Enabled = $true
        Path = $targetOU
        AccountPassword = (ConvertTo-SecureString -String $password -AsPlainText -Force)
        ChangePasswordAtLogon = $true
    }
    $newUser = New-ADUser @userParams

    # Add the user to the matching groups
    $userGroups = $user.Groups -split ","
    foreach ($group in $userGroups) {
        Add-ADGroupMember -Identity $group -Members $newUser
    }

    # Output the user details and the groups they were added to
    [PSCustomObject]@{
        Name = $newUser.Name
        Username = $username
        Email = $email
        Password = $password
        Groups = $userGroups -join ","
    }
}

# Export the user details to a CSV file
$results | Export-Csv -Path "C:\output.csv" -NoTypeInformation
Write-Host "User details exported to output.csv"
