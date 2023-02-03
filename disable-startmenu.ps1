If ($User -eq "UserName") {
  Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\Start_TrackProgs" -Force
  New-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_TrackProgs" -Value 0 -Force
}
