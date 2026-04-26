function Toggle-Service {
  param (
    [string]$ServiceName
  )

  $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

  if ($service) {
    if ($service.Status -eq "Running") {
      Write-Host "Stopping service $ServiceName..."
      $service | Stop-Service
    } else {
      Write-Host "Starting service $ServiceName..."
      $service | Start-Service
    }
  } else {
    Write-Host "Service $ServiceName not found"
  }
}

