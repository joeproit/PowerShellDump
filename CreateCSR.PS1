$certificateName = Read-Host "Enter the certificate name"
$country = Read-Host "Enter the country code (e.g. US)"
$state = Read-Host "Enter the state or province name"
$locality = Read-Host "Enter the locality or city name"
$organization = Read-Host "Enter the organization name"
$organizationUnit = Read-Host "Enter the organizational unit name"
$commonName = Read-Host "Enter the common name (e.g. example.com)"

$subject = @{
  "CN" = $commonName;
  "O" = $organization;
  "OU" = $organizationUnit;
  "L" = $locality;
  "S" = $state;
  "C" = $country
}

$certificateRequest = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
$certificateRequest.Subject = $subject
$certificateRequest.KeyAlgorithm = "RSA"
$certificateRequest.KeyLength = 2048
$certificateRequest.FriendlyName = $certificateName
$certificateRequest.SignatureAlgorithm = "sha256"

$certificateRequest.Export("Cert") | Out-File "$certificateName.csr"
