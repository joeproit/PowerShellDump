BeforeAll {
    . $PSScriptRoot/05_FactoryMethod.ps1
}

Describe 'CryptoAlgorithmFactory' {
    Context 'Create(string) - parameterless overload' {
        It 'Returns AesCryptoAlgorithm for AES-256-GCM' {
            $result = [CryptoAlgorithmFactory]::Create('AES-256-GCM')
            
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType ([AesCryptoAlgorithm])
            $result.Name | Should -Be 'AES-256-GCM'
        }

        It 'Returns AesCryptoAlgorithm for case variations' {
            $testCases = @(
                @{ Input = 'aes-256-gcm' }
                @{ Input = 'AES-256-GCM' }
                @{ Input = 'Aes-256-Gcm' }
            )
            
            $testCases | ForEach-Object {
                $result = [CryptoAlgorithmFactory]::Create($_.Input)
                $result | Should -BeOfType ([AesCryptoAlgorithm])
            }
        }

        It 'Generates a random 32-byte key for AES' {
            $result = [CryptoAlgorithmFactory]::Create('AES-256-GCM')
            $key = $result.GetKey()
            
            $key | Should -Not -BeNullOrEmpty
            $key.Length | Should -Be 32
            
            # Verify it's not all zeros (random)
            $nonZeroCount = ($key | Where-Object { $_ -ne 0 }).Count
            $nonZeroCount | Should -BeGreaterThan 0
        }

        It 'Throws NotSupportedException for ChaCha20' {
            { [CryptoAlgorithmFactory]::Create('ChaCha20') } | 
                Should -Throw -ExceptionType ([System.NotSupportedException]) -ExpectedMessage '*ChaCha20*not yet implemented*'
        }

        It 'Throws NotSupportedException for ChaCha20 case variations' {
            $testCases = @('ChaCha20', 'chacha20', 'CHACHA20', 'ChAcHa20')
            
            $testCases | ForEach-Object {
                { [CryptoAlgorithmFactory]::Create($_) } | 
                    Should -Throw -ExceptionType ([System.NotSupportedException])
            }
        }

        It 'Throws ArgumentException for unknown algorithm' {
            { [CryptoAlgorithmFactory]::Create('TripleDES') } | 
                Should -Throw -ExceptionType ([System.ArgumentException]) -ExpectedMessage '*Unknown algorithm*'
        }

        It 'Throws ArgumentException for empty string' {
            { [CryptoAlgorithmFactory]::Create('') } | 
                Should -Throw -ExceptionType ([System.ArgumentException])
        }

        It 'Throws ArgumentException for invalid algorithm names' {
            $testCases = @('RSA', 'DES', 'BlowFish', 'NotAnAlgorithm', 'SHA256')
            
            $testCases | ForEach-Object {
                { [CryptoAlgorithmFactory]::Create($_) } | 
                    Should -Throw -ExceptionType ([System.ArgumentException])
            }
        }
    }

    Context 'Create(string, byte[]) - keyed overload' {
        It 'Returns AesCryptoAlgorithm with provided key' {
            $key = [byte[]]::new(32)
            for ($i = 0; $i -lt 32; $i++) { $key[$i] = $i }
            
            $result = [CryptoAlgorithmFactory]::Create('AES-256-GCM', $key)
            
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType ([AesCryptoAlgorithm])
            $result.Name | Should -Be 'AES-256-GCM'
        }

        It 'Sets the key correctly in the returned instance' {
            $key = [byte[]]::new(32)
            for ($i = 0; $i -lt 32; $i++) { $key[$i] = ($i * 2) % 256 }
            
            $result = [CryptoAlgorithmFactory]::Create('AES-256-GCM', $key)
            $actualKey = $result.GetKey()
            
            $actualKey.Length | Should -Be $key.Length
            for ($i = 0; $i -lt $key.Length; $i++) {
                $actualKey[$i] | Should -Be $key[$i]
            }
        }

        It 'Accepts different valid 32-byte keys' {
            # All zeros
            $key1 = [byte[]]::new(32)
            $result1 = [CryptoAlgorithmFactory]::Create('AES-256-GCM', $key1)
            $result1 | Should -BeOfType ([AesCryptoAlgorithm])
            
            # All 255s
            $key2 = [byte[]]::new(32)
            for ($i = 0; $i -lt 32; $i++) { $key2[$i] = 255 }
            $result2 = [CryptoAlgorithmFactory]::Create('AES-256-GCM', $key2)
            $result2 | Should -BeOfType ([AesCryptoAlgorithm])
            
            # Random
            $key3 = [byte[]]::new(32)
            [System.Security.Cryptography.RandomNumberGenerator]::Fill($key3)
            $result3 = [CryptoAlgorithmFactory]::Create('AES-256-GCM', $key3)
            $result3 | Should -BeOfType ([AesCryptoAlgorithm])
        }

        It 'Throws NotSupportedException for ChaCha20 with key' {
            $key = [byte[]]::new(32)
            
            { [CryptoAlgorithmFactory]::Create('ChaCha20', $key) } | 
                Should -Throw -ExceptionType ([System.NotSupportedException]) -ExpectedMessage '*ChaCha20*not yet implemented*'
        }

        It 'Throws ArgumentException for unknown algorithm with key' {
            $key = [byte[]]::new(32)
            
            { [CryptoAlgorithmFactory]::Create('TripleDES', $key) } | 
                Should -Throw -ExceptionType ([System.ArgumentException]) -ExpectedMessage '*Key overload not supported*'
        }

        It 'Handles case insensitivity for keyed overload' {
            $key = [byte[]]::new(32)
            $testCases = @('aes-256-gcm', 'AES-256-GCM', 'Aes-256-Gcm')
            
            $testCases | ForEach-Object {
                $result = [CryptoAlgorithmFactory]::Create($_, $key)
                $result | Should -BeOfType ([AesCryptoAlgorithm])
            }
        }
    }

    Context 'Factory integration with encryption' {
        It 'Created algorithm can encrypt data' {
            $algo = [CryptoAlgorithmFactory]::Create('AES-256-GCM')
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('Test data')
            
            $ciphertext = $algo.Encrypt($plaintext)
            
            $ciphertext | Should -Not -BeNullOrEmpty
            $ciphertext.Length | Should -BeGreaterThan $plaintext.Length
            # AES-GCM adds 12-byte nonce + 16-byte tag = 28 bytes overhead
            $ciphertext.Length | Should -Be ($plaintext.Length + 28)
        }

        It 'Keyed algorithm can encrypt data' {
            $key = [byte[]]::new(32)
            [System.Security.Cryptography.RandomNumberGenerator]::Fill($key)
            $algo = [CryptoAlgorithmFactory]::Create('AES-256-GCM', $key)
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('Keyed encryption test')
            
            $ciphertext = $algo.Encrypt($plaintext)
            
            $ciphertext | Should -Not -BeNullOrEmpty
            $ciphertext.Length | Should -Be ($plaintext.Length + 28)
        }

        It 'Different instances produce different ciphertexts for same plaintext' {
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('Same data')
            $algo1 = [CryptoAlgorithmFactory]::Create('AES-256-GCM')
            $algo2 = [CryptoAlgorithmFactory]::Create('AES-256-GCM')
            
            $ct1 = $algo1.Encrypt($plaintext)
            $ct2 = $algo2.Encrypt($plaintext)
            
            # Different because different random keys and nonces
            $ct1 | Should -Not -Be $ct2
        }
    }

    Context 'Error handling edge cases' {
        It 'Handles null algorithm name gracefully' {
            # In PS 7.4.6 arm64, null may resolve to empty string rather than throw
            $errorOccurred = $false
            try {
                [CryptoAlgorithmFactory]::Create($null)
            }
            catch {
                $errorOccurred = $true
                $_.Exception | Should -BeOfType ([System.ArgumentException])
            }
            $errorOccurred | Should -BeTrue
        }

        It 'Throws for whitespace-only algorithm name' {
            { [CryptoAlgorithmFactory]::Create('   ') } | 
                Should -Throw -ExceptionType ([System.ArgumentException])
        }
    }
}

Describe 'AesCryptoAlgorithm' {
    Context 'Direct instantiation' {
        It 'Can be created with a 32-byte key' {
            $key = [byte[]]::new(32)
            [System.Security.Cryptography.RandomNumberGenerator]::Fill($key)
            
            $algo = [AesCryptoAlgorithm]::new($key)
            
            $algo | Should -Not -BeNullOrEmpty
            $algo.Name | Should -Be 'AES-256-GCM'
        }

        It 'GetKey returns the provided key' {
            $key = [byte[]]::new(32)
            for ($i = 0; $i -lt 32; $i++) { $key[$i] = $i }
            
            $algo = [AesCryptoAlgorithm]::new($key)
            $retrievedKey = $algo.GetKey()
            
            $retrievedKey.Length | Should -Be 32
            for ($i = 0; $i -lt 32; $i++) {
                $retrievedKey[$i] | Should -Be $key[$i]
            }
        }

        It 'Encrypts data successfully' {
            $key = [byte[]]::new(32)
            [System.Security.Cryptography.RandomNumberGenerator]::Fill($key)
            $algo = [AesCryptoAlgorithm]::new($key)
            $data = [System.Text.Encoding]::UTF8.GetBytes('Secret message')
            
            $result = $algo.Encrypt($data)
            
            $result | Should -Not -BeNullOrEmpty
            $result.Length | Should -Be ($data.Length + 28)
        }
    }
}

Describe 'CryptoAlgorithm base class' {
    Context 'Base class behavior' {
        It 'Throws NotImplementedException when Encrypt is called on base class' {
            $algo = [CryptoAlgorithm]::new('TestAlgo')
            $data = [byte[]]::new(10)
            
            { $algo.Encrypt($data) } | 
                Should -Throw -ExceptionType ([System.NotImplementedException])
        }

        It 'Stores name correctly' {
            $algo = [CryptoAlgorithm]::new('CustomName')
            $algo.Name | Should -Be 'CustomName'
        }
    }
}
