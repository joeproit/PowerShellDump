BeforeAll {
    . $PSScriptRoot/24_AlgorithmAgility.ps1
}

Describe 'ProfileFactory' {
    It 'Returns the default CryptoProfile for default aliases' {
        $profiles = @('default', 'CryptoProfile', 'v1', '1')

        foreach ($name in $profiles) {
            $profile = [ProfileFactory]::Create($name)

            $profile.GetType().Name | Should -Be 'CryptoProfile'
            $profile.CipherAlgorithm | Should -Be 'AES-256-GCM'
            $profile.HashAlgorithm | Should -Be 'SHA-256'
            $profile.KdfIterations | Should -Be 200000
        }
    }

    It 'Returns a Fips140Profile for FIPS aliases' {
        $profiles = @('fips140', 'Fips140Profile', 'FIPS140-2024', 'fips')

        foreach ($name in $profiles) {
            $profile = [ProfileFactory]::Create($name)

            $profile.GetType().Name | Should -Be 'Fips140Profile'
            $profile.CipherAlgorithm | Should -Be 'AES-256-GCM'
            $profile.HashAlgorithm | Should -Be 'SHA-384'
            $profile.KdfAlgorithm | Should -Be 'PBKDF2-SHA256'
            $profile.KdfIterations | Should -Be 310000
        }
    }

    It 'Throws for unknown profile names' {
        { [ProfileFactory]::Create('unknown-profile') } |
            Should -Throw -ExceptionType ([System.ArgumentException])
    }
}

Describe 'AgileEncryptor' {
    Context 'Hash behavior' {
        It 'Uses the profile hash algorithm for the default profile' {
            $profile = [ProfileFactory]::Create('default')
            $encryptor = [AgileEncryptor]::new($profile)
            $data = [System.Text.Encoding]::UTF8.GetBytes('hash me')

            $actual = $encryptor.Hash($data)
            $expected = [System.Security.Cryptography.SHA256]::Create().ComputeHash($data)

            $actual.Length | Should -Be 32
            $actual | Should -Be $expected
        }

        It 'Uses the profile hash algorithm for the FIPS profile' {
            $profile = [ProfileFactory]::Create('fips140')
            $encryptor = [AgileEncryptor]::new($profile)
            $data = [System.Text.Encoding]::UTF8.GetBytes('hash me')

            $actual = $encryptor.Hash($data)
            $expected = [System.Security.Cryptography.SHA384]::Create().ComputeHash($data)

            $actual.Length | Should -Be 48
            $actual | Should -Be $expected
        }

        It 'Hashes null input as an empty byte array' {
            $encryptor = [AgileEncryptor]::new([ProfileFactory]::Create('default'))
            $actual = $encryptor.Hash($null)
            $expected = $encryptor.Hash([byte[]]::new(0))

            $actual | Should -Be $expected
            $actual.Length | Should -Be 32
        }

        It 'Changes hash output when the profile changes' {
            $data = [System.Text.Encoding]::UTF8.GetBytes('profile swap')
            $defaultEncryptor = [AgileEncryptor]::new([ProfileFactory]::Create('default'))
            $fipsEncryptor = [AgileEncryptor]::new([ProfileFactory]::Create('fips140'))

            $defaultHash = $defaultEncryptor.Hash($data)
            $fipsHash = $fipsEncryptor.Hash($data)

            $defaultHash.Length | Should -Be 32
            $fipsHash.Length | Should -Be 48
            $defaultHash | Should -Not -Be $fipsHash
        }
    }

    Context 'Encryption package metadata' {
        It 'Stores the profile version in the encrypted package' {
            $profile = [ProfileFactory]::Create('default')
            $encryptor = [AgileEncryptor]::new($profile)
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('versioned payload')

            $package = $encryptor.Encrypt($plaintext)

            $package.Profile | Should -Be $profile.Version
            $package.Algorithm | Should -Be $profile.CipherAlgorithm
        }

        It 'Round-trips ciphertext with the FIPS profile' {
            $profile = [ProfileFactory]::Create('fips140')
            $encryptor = [AgileEncryptor]::new($profile)
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('round trip')

            $package = $encryptor.Encrypt($plaintext)
            $decrypted = $encryptor.Decrypt($package)

            $package.Profile | Should -Be $profile.Version
            $decrypted | Should -Be $plaintext
        }

        It 'Round-trips ciphertext with the default profile' {
            $profile = [ProfileFactory]::Create('default')
            $encryptor = [AgileEncryptor]::new($profile)
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('round trip')

            $package = $encryptor.Encrypt($plaintext)
            $decrypted = $encryptor.Decrypt($package)

            $package.Profile | Should -Be $profile.Version
            $decrypted | Should -Be $plaintext
        }
    }
}
