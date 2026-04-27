BeforeAll {
    . $PSScriptRoot/27_CertChainValidation.ps1

    function New-CertificateFixture {
        $root = Join-Path $TestDrive 'certchainvalidation'
        $null = New-Item -ItemType Directory -Path $root -Force

        if ($IsWindows) {
            $subject = 'CN=CertChainValidation Test'
            $cert = New-SelfSignedCertificate `
                -Subject $subject `
                -CertStoreLocation 'Cert:\CurrentUser\My' `
                -KeyExportPolicy Exportable `
                -NotAfter (Get-Date).AddDays(5)

            $cerPath = Join-Path $root 'cert.cer'
            $null = Export-Certificate -Cert $cert -FilePath $cerPath -Force

            return [pscustomobject]@{
                CerPath = $cerPath
                Cert    = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($cerPath)
                StoreId = $cert.PSPath
            }
        }

        $keyPath = Join-Path $root 'cert.key'
        $pemPath = Join-Path $root 'cert.pem'
        $cerPath = Join-Path $root 'cert.cer'

        & openssl req -x509 -newkey rsa:2048 -keyout $keyPath -out $pemPath -days 5 -nodes -subj '/CN=CertChainValidation Test' *> $null
        if ($LASTEXITCODE -ne 0) { throw 'openssl req failed' }

        & openssl x509 -in $pemPath -outform der -out $cerPath *> $null
        if ($LASTEXITCODE -ne 0) { throw 'openssl x509 failed' }

        return [pscustomobject]@{
            CerPath = $cerPath
            Cert    = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($cerPath)
            StoreId = $null
        }
    }

    $script:Fixture = New-CertificateFixture
}

AfterAll {
    if ($script:Fixture.Cert) {
        $script:Fixture.Cert.Dispose()
    }

    if ($IsWindows -and $script:Fixture.StoreId) {
        Remove-Item $script:Fixture.StoreId -ErrorAction SilentlyContinue
    }
}

Describe 'CertificateValidator' {
    It 'exposes a development preset that skips revocation and allows untrusted roots' {
        $validator = [CertificateValidator]::Development()

        $validator.CheckRevocation | Should -BeFalse
        $validator.AllowUntrustedRoot | Should -BeTrue
    }

    It 'validates a self-signed certificate from disk in development mode' {
        $validator = [CertificateValidator]::Development()

        $result = $validator.ValidateFromFile($script:Fixture.CerPath)

        $result.IsValid | Should -BeTrue
        $result.Errors.Count | Should -Be 0
        $result.ChainInfo.Count | Should -BeGreaterThan 0
        $result.ChainInfo[0].Subject | Should -Match 'CertChainValidation Test'
    }

    It 'flags an expired certificate in strict mode' {
        $validator = [CertificateValidator]::Strict()
        $validator.ValidAt = $script:Fixture.Cert.NotAfter.AddDays(1)

        $result = $validator.ValidateFromFile($script:Fixture.CerPath)

        $result.IsValid | Should -BeFalse
        ($result.Errors -join ';') | Should -Match 'Certificate expired or not yet valid'
    }
}
