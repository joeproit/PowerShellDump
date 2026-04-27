<#
.SYNOPSIS
    OOP Reference: Certificate Chain Validation
.DESCRIPTION
    Topic:        X.509 chain building, thumbprint pinning, revocation modes
    Category:     Advanced Crypto
    Agent Task:   Add a ValidateFromFile([string]$certPath) convenience method.
                  Add a static Development() factory that skips revocation + allows untrusted root.
                  Add Pester tests (use self-signed cert generated via New-SelfSignedCertificate
                  on Windows or openssl on Linux for test fixtures).
    Done Conditions:
      - Strict() mode catches expired certs
      - Development() mode accepts self-signed without error
      - Pester tests pass: Invoke-Pester -Output Detailed
    Non-Scope:
      - No OCSP stapling
      - No CRL distribution point fetching in unit tests (use NoCheck revocation mode)
#>

class CertificateValidator {
    [bool]$AllowUntrustedRoot = $false
    [bool]$CheckRevocation    = $true
    [datetime]$ValidAt        = [datetime]::UtcNow
    [System.Collections.Generic.List[string]]$TrustedThumbprints

    CertificateValidator() {
        $this.TrustedThumbprints = [System.Collections.Generic.List[string]]::new()
    }

    [hashtable] Validate([System.Security.Cryptography.X509Certificates.X509Certificate2]$cert) {
        $result = @{
            IsValid   = $false
            Errors    = [System.Collections.Generic.List[string]]::new()
            ChainInfo = $null
        }

        if ($this.ValidAt -lt $cert.NotBefore -or $this.ValidAt -gt $cert.NotAfter) {
            $result.Errors.Add('Certificate expired or not yet valid')
        }

        $chain = [System.Security.Cryptography.X509Certificates.X509Chain]::new()
        $chain.ChainPolicy.RevocationMode = $this.CheckRevocation ?
            [System.Security.Cryptography.X509Certificates.X509RevocationMode]::Online :
            [System.Security.Cryptography.X509Certificates.X509RevocationMode]::NoCheck

        if ($this.AllowUntrustedRoot) {
            $chain.ChainPolicy.VerificationFlags =
                [System.Security.Cryptography.X509Certificates.X509VerificationFlags]::AllowUnknownCertificateAuthority
        }

        $chainValid   = $chain.Build($cert)
        $result.ChainInfo = $chain.ChainElements | Select-Object `
            @{N='Subject';E={$_.Certificate.Subject}},
            @{N='Thumbprint';E={$_.Certificate.Thumbprint}},
            @{N='Expires';E={$_.Certificate.NotAfter}}

        if (-not $chainValid) {
            foreach ($s in $chain.ChainStatus) {
                $result.Errors.Add("Chain: $($s.StatusInformation.Trim())")
            }
        }

        if ($this.TrustedThumbprints.Count -gt 0 -and
            -not $this.TrustedThumbprints.Contains($cert.Thumbprint)) {
            $result.Errors.Add('Certificate thumbprint not in pinned set')
        }

        $result.IsValid = ($result.Errors.Count -eq 0 -and $chainValid)
        $chain.Dispose()
        return $result
    }

    [hashtable] ValidateFromFile([string]$certPath) {
        if ([string]::IsNullOrWhiteSpace($certPath)) {
            throw [System.ArgumentException]::new('certPath cannot be null or empty', 'certPath')
        }

        $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($certPath)
        try {
            return $this.Validate($cert)
        }
        finally {
            $cert.Dispose()
        }
    }

    static [CertificateValidator] Strict() {
        $v = [CertificateValidator]::new()
        $v.CheckRevocation    = $true
        $v.AllowUntrustedRoot = $false
        return $v
    }

    static [CertificateValidator] Development() {
        $v = [CertificateValidator]::new()
        $v.CheckRevocation    = $false
        $v.AllowUntrustedRoot = $true
        return $v
    }
}
