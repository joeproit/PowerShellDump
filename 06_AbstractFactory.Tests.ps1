BeforeAll {
    . $PSScriptRoot/06_AbstractFactory.ps1
}

Describe '06_AbstractFactory - FIPS Suite' {
    BeforeEach {
        $factory = [FipsCryptoSuiteFactory]::new()
    }

    It 'creates FIPS cipher' {
        $cipher = $factory.CreateCipher()
        $cipher | Should -Not -BeNullOrEmpty
        $cipher.GetType().Name | Should -Be 'FipsAesCipher'
    }

    It 'creates FIPS signer' {
        $signer = $factory.CreateSigner()
        $signer | Should -Not -BeNullOrEmpty
        $signer.GetType().Name | Should -Be 'FipsRsaSigner'
    }

    It 'creates SHA256 hasher' {
        $hasher = $factory.CreateHasher()
        $hasher | Should -Not -BeNullOrEmpty
        $hasher.GetType().Name | Should -Be 'Sha256Hasher'
    }

    It 'FIPS cipher encrypts and decrypts' {
        $cipher = $factory.CreateCipher()
        $pt = [System.Text.Encoding]::UTF8.GetBytes('Hello FIPS')
        $ct = $cipher.Seal($pt)
        $ct | Should -Not -BeNullOrEmpty
        $ct.Length | Should -BeGreaterThan $pt.Length
        
        $decrypted = $cipher.Open($ct)
        $decrypted | Should -Be $pt
        [System.Text.Encoding]::UTF8.GetString($decrypted) | Should -Be 'Hello FIPS'
    }

    It 'FIPS signer signs and verifies' {
        $signer = $factory.CreateSigner()
        $data = [System.Text.Encoding]::UTF8.GetBytes('Sign this')
        $sig = $signer.Sign($data)
        $sig | Should -Not -BeNullOrEmpty
        $signer.Verify($data, $sig) | Should -BeTrue
    }

    It 'FIPS signer rejects tampered data' {
        $signer = $factory.CreateSigner()
        $data = [System.Text.Encoding]::UTF8.GetBytes('Original')
        $sig = $signer.Sign($data)
        $tampered = [System.Text.Encoding]::UTF8.GetBytes('Tampered')
        $signer.Verify($tampered, $sig) | Should -BeFalse
    }

    It 'SHA256 hasher produces 32-byte hash' {
        $hasher = $factory.CreateHasher()
        $data = [System.Text.Encoding]::UTF8.GetBytes('Hash me')
        $hash = $hasher.Hash($data)
        $hash | Should -Not -BeNullOrEmpty
        $hash.Length | Should -Be 32
    }
}

Describe '06_AbstractFactory - Legacy Suite' {
    BeforeEach {
        $factory = [LegacyCryptoSuiteFactory]::new()
    }

    It 'creates Legacy cipher' {
        $cipher = $factory.CreateCipher()
        $cipher | Should -Not -BeNullOrEmpty
        $cipher.GetType().Name | Should -Be 'LegacyAesCipher'
    }

    It 'creates Legacy signer' {
        $signer = $factory.CreateSigner()
        $signer | Should -Not -BeNullOrEmpty
        $signer.GetType().Name | Should -Be 'LegacyHmacSigner'
    }

    It 'creates MD5 hasher' {
        $hasher = $factory.CreateHasher()
        $hasher | Should -Not -BeNullOrEmpty
        $hasher.GetType().Name | Should -Be 'Md5Hasher'
    }

    It 'Legacy cipher encrypts and decrypts' {
        $cipher = $factory.CreateCipher()
        $pt = [System.Text.Encoding]::UTF8.GetBytes('Hello Legacy')
        $ct = $cipher.Seal($pt)
        $ct | Should -Not -BeNullOrEmpty
        $ct.Length | Should -BeGreaterThan $pt.Length
        
        $decrypted = $cipher.Open($ct)
        $decrypted | Should -Be $pt
        [System.Text.Encoding]::UTF8.GetString($decrypted) | Should -Be 'Hello Legacy'
    }

    It 'Legacy signer signs and verifies' {
        $signer = $factory.CreateSigner()
        $data = [System.Text.Encoding]::UTF8.GetBytes('Sign this legacy')
        $sig = $signer.Sign($data)
        $sig | Should -Not -BeNullOrEmpty
        $signer.Verify($data, $sig) | Should -BeTrue
    }

    It 'Legacy signer rejects tampered data' {
        $signer = $factory.CreateSigner()
        $data = [System.Text.Encoding]::UTF8.GetBytes('Original')
        $sig = $signer.Sign($data)
        $tampered = [System.Text.Encoding]::UTF8.GetBytes('Tampered')
        $signer.Verify($tampered, $sig) | Should -BeFalse
    }

    It 'MD5 hasher produces 16-byte hash' {
        $hasher = $factory.CreateHasher()
        $data = [System.Text.Encoding]::UTF8.GetBytes('Hash me')
        $hash = $hasher.Hash($data)
        $hash | Should -Not -BeNullOrEmpty
        $hash.Length | Should -Be 16
    }
}

Describe '06_AbstractFactory - Factory Selector' {
    It 'returns FIPS factory for "fips" suite' {
        $factory = Get-CryptoSuiteFactory -Suite 'fips'
        $factory | Should -Not -BeNullOrEmpty
        $factory.GetType().Name | Should -Be 'FipsCryptoSuiteFactory'
    }

    It 'returns Legacy factory for "legacy" suite' {
        $factory = Get-CryptoSuiteFactory -Suite 'legacy'
        $factory | Should -Not -BeNullOrEmpty
        $factory.GetType().Name | Should -Be 'LegacyCryptoSuiteFactory'
    }

    It 'rejects invalid suite name' {
        { Get-CryptoSuiteFactory -Suite 'invalid' } | Should -Throw
    }
}

Describe '06_AbstractFactory - SecureChannel with FIPS' {
    BeforeEach {
        $factory = [FipsCryptoSuiteFactory]::new()
        $channel = [SecureChannel]::new($factory)
    }

    It 'sends and receives message with FIPS suite' {
        $original = [System.Text.Encoding]::UTF8.GetBytes('Secret FIPS message')
        $packet = $channel.Send($original)
        
        $packet | Should -Not -BeNullOrEmpty
        $packet.Sealed | Should -Not -BeNullOrEmpty
        $packet.Signature | Should -Not -BeNullOrEmpty
        $packet.Hash | Should -Not -BeNullOrEmpty
        
        $received = $channel.Receive($packet)
        $received | Should -Be $original
        [System.Text.Encoding]::UTF8.GetString($received) | Should -Be 'Secret FIPS message'
    }

    It 'rejects tampered sealed data' {
        $original = [System.Text.Encoding]::UTF8.GetBytes('Secret message')
        $packet = $channel.Send($original)
        
        # Tamper with sealed data
        $packet.Sealed[0] = $packet.Sealed[0] -bxor 0xFF
        
        { $channel.Receive($packet) } | Should -Throw -ExceptionType ([System.Security.SecurityException])
    }

    It 'hash is SHA256 (32 bytes)' {
        $original = [System.Text.Encoding]::UTF8.GetBytes('Hash test')
        $packet = $channel.Send($original)
        $packet.Hash.Length | Should -Be 32
    }
}

Describe '06_AbstractFactory - SecureChannel with Legacy' {
    BeforeEach {
        $factory = [LegacyCryptoSuiteFactory]::new()
        $channel = [SecureChannel]::new($factory)
    }

    It 'sends and receives message with Legacy suite' {
        $original = [System.Text.Encoding]::UTF8.GetBytes('Secret Legacy message')
        $packet = $channel.Send($original)
        
        $packet | Should -Not -BeNullOrEmpty
        $packet.Sealed | Should -Not -BeNullOrEmpty
        $packet.Signature | Should -Not -BeNullOrEmpty
        $packet.Hash | Should -Not -BeNullOrEmpty
        
        $received = $channel.Receive($packet)
        $received | Should -Be $original
        [System.Text.Encoding]::UTF8.GetString($received) | Should -Be 'Secret Legacy message'
    }

    It 'rejects tampered sealed data' {
        $original = [System.Text.Encoding]::UTF8.GetBytes('Secret message')
        $packet = $channel.Send($original)
        
        # Tamper with sealed data
        $packet.Sealed[0] = $packet.Sealed[0] -bxor 0xFF
        
        { $channel.Receive($packet) } | Should -Throw -ExceptionType ([System.Security.SecurityException])
    }

    It 'hash is MD5 (16 bytes)' {
        $original = [System.Text.Encoding]::UTF8.GetBytes('Hash test')
        $packet = $channel.Send($original)
        $packet.Hash.Length | Should -Be 16
    }
}

Describe '06_AbstractFactory - Cross-Suite Independence' {
    It 'SecureChannel works with both factories without modification' {
        $fipsFactory = [FipsCryptoSuiteFactory]::new()
        $legacyFactory = [LegacyCryptoSuiteFactory]::new()
        
        $fipsChannel = [SecureChannel]::new($fipsFactory)
        $legacyChannel = [SecureChannel]::new($legacyFactory)
        
        $msg = [System.Text.Encoding]::UTF8.GetBytes('Test message')
        
        # Both channels work independently
        $fipsPacket = $fipsChannel.Send($msg)
        $legacyPacket = $legacyChannel.Send($msg)
        
        $fipsReceived = $fipsChannel.Receive($fipsPacket)
        $legacyReceived = $legacyChannel.Receive($legacyPacket)
        
        $fipsReceived | Should -Be $msg
        $legacyReceived | Should -Be $msg
    }

    It 'packets from different suites are incompatible' {
        $fipsFactory = [FipsCryptoSuiteFactory]::new()
        $legacyFactory = [LegacyCryptoSuiteFactory]::new()
        
        $fipsChannel = [SecureChannel]::new($fipsFactory)
        $legacyChannel = [SecureChannel]::new($legacyFactory)
        
        $msg = [System.Text.Encoding]::UTF8.GetBytes('Test')
        $fipsPacket = $fipsChannel.Send($msg)
        
        # Legacy channel cannot verify FIPS packet
        { $legacyChannel.Receive($fipsPacket) } | Should -Throw
    }
}
