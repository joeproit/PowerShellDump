Add-Type -AssemblyName System.Windows.Forms

$ButtonType = [System.Windows.Forms.MessageBoxButtons]::YesNoCancel
$MessageIcon = [System.Windows.Forms.MessageBoxIcon]::Information
$MessageTitle = "Message Box Title"
$MessageBody = "This is your message box text."

$Result = [System.Windows.Forms.MessageBox]::Show($MessageBody, $MessageTitle, $ButtonType, $MessageIcon)

# Check the result
switch($Result) {
    "Yes" {
        Write-Host "You clicked Yes!"
    }
    "No" {
        Write-Host "You clicked No!"
    }
    "Cancel" {
        Write-Host "You clicked Cancel!"
    }
}
