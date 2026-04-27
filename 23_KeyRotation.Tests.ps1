BeforeAll {
    . $PSScriptRoot/23_KeyRotation.ps1
}

Describe 'RotatingKeyManager' {
    Context 'Basic functionality' {
        It 'Creates manager with default retention count' {
            $mgr = [RotatingKeyManager]::new(3)
            $mgr.GetRetainedKeyIds().Count | Should -Be 1
        }

        It 'Creates manager with custom retention count' {
            $mgr = [RotatingKeyManager]::new(5)
            $mgr.GetRetainedKeyIds().Count | Should -Be 1
        }

        It 'Encrypts and decrypts successfully' {
            $mgr = [RotatingKeyManager]::new(3)
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('test data')
            
            $result = $mgr.Encrypt($plaintext)
            $result.KeyId | Should -Not -BeNullOrEmpty
            $result.Ciphertext | Should -Not -BeNullOrEmpty
            
            $decrypted = $mgr.Decrypt($result.KeyId, $result.Ciphertext)
            [System.Text.Encoding]::UTF8.GetString($decrypted) | Should -Be 'test data'
        }
    }

    Context 'Key rotation' {
        It 'Rotates keys and retains old keys' {
            $mgr = [RotatingKeyManager]::new(3)
            $key1 = $mgr.GetCurrentKeyId()
            
            Start-Sleep -Milliseconds 10
            $mgr.Rotate()
            $key2 = $mgr.GetCurrentKeyId()
            
            $key2 | Should -Not -Be $key1
            $mgr.GetRetainedKeyIds().Count | Should -Be 2
            $mgr.GetRetainedKeyIds() | Should -Contain $key1
            $mgr.GetRetainedKeyIds() | Should -Contain $key2
        }

        It 'Uses current key for encryption after rotation' {
            $mgr = [RotatingKeyManager]::new(3)
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('data')
            
            Start-Sleep -Milliseconds 10
            $mgr.Rotate()
            $currentKey = $mgr.GetCurrentKeyId()
            
            $result = $mgr.Encrypt($plaintext)
            $result.KeyId | Should -Be $currentKey
        }

        It 'Decrypts with old retained keys' {
            $mgr = [RotatingKeyManager]::new(3)
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('encrypted with old key')
            
            # Encrypt with first key
            $result1 = $mgr.Encrypt($plaintext)
            $oldKeyId = $result1.KeyId
            
            # Rotate to new key
            Start-Sleep -Milliseconds 10
            $mgr.Rotate()
            
            # Should still decrypt with old key
            $decrypted = $mgr.Decrypt($oldKeyId, $result1.Ciphertext)
            [System.Text.Encoding]::UTF8.GetString($decrypted) | Should -Be 'encrypted with old key'
        }
    }

    Context 'Key pruning beyond retainCount' {
        It 'Prunes oldest key when exceeding retention count' {
            $mgr = [RotatingKeyManager]::new(2)
            $key1 = $mgr.GetCurrentKeyId()
            
            Start-Sleep -Milliseconds 10
            $mgr.Rotate()
            $key2 = $mgr.GetCurrentKeyId()
            
            Start-Sleep -Milliseconds 10
            $mgr.Rotate()
            $key3 = $mgr.GetCurrentKeyId()
            
            # Should have exactly 2 keys
            $mgr.GetRetainedKeyIds().Count | Should -Be 2
            # Should contain newest keys
            $mgr.GetRetainedKeyIds() | Should -Contain $key2
            $mgr.GetRetainedKeyIds() | Should -Contain $key3
            # Should NOT contain oldest key
            $mgr.GetRetainedKeyIds() | Should -Not -Contain $key1
        }

        It 'Throws CryptographicException for pruned key' {
            $mgr = [RotatingKeyManager]::new(2)
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('test')
            
            # Encrypt with first key
            $result = $mgr.Encrypt($plaintext)
            $prunedKeyId = $result.KeyId
            
            # Rotate twice to prune the first key
            Start-Sleep -Milliseconds 10
            $mgr.Rotate()
            Start-Sleep -Milliseconds 10
            $mgr.Rotate()
            
            # Attempt to decrypt with pruned key should throw
            { $mgr.Decrypt($prunedKeyId, $result.Ciphertext) } | Should -Throw -ExceptionType ([System.Security.Cryptography.CryptographicException])
        }

        It 'Throws CryptographicException with correct message for missing key' {
            $mgr = [RotatingKeyManager]::new(2)
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('data')
            $result = $mgr.Encrypt($plaintext)
            $prunedKeyId = $result.KeyId
            
            # Prune the key
            Start-Sleep -Milliseconds 10
            $mgr.Rotate()
            Start-Sleep -Milliseconds 10
            $mgr.Rotate()
            
            { $mgr.Decrypt($prunedKeyId, $result.Ciphertext) } | Should -Throw "*not available*"
        }
    }

    Context 'ReEncrypt method' {
        It 'ReEncrypts from old key to current key' {
            $mgr = [RotatingKeyManager]::new(3)
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('sensitive data')
            
            # Encrypt with initial key
            $result1 = $mgr.Encrypt($plaintext)
            $oldKeyId = $result1.KeyId
            
            # Rotate to new key
            Start-Sleep -Milliseconds 10
            $mgr.Rotate()
            $newKeyId = $mgr.GetCurrentKeyId()
            
            # ReEncrypt
            $result2 = $mgr.ReEncrypt($oldKeyId, $result1.Ciphertext)
            
            # Should be encrypted with current key
            $result2.KeyId | Should -Be $newKeyId
            $result2.KeyId | Should -Not -Be $oldKeyId
            
            # Should decrypt to same plaintext
            $decrypted = $mgr.Decrypt($result2.KeyId, $result2.Ciphertext)
            [System.Text.Encoding]::UTF8.GetString($decrypted) | Should -Be 'sensitive data'
        }

        It 'Throws when ReEncrypting with pruned key' {
            $mgr = [RotatingKeyManager]::new(2)
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('data')
            
            # Encrypt with first key
            $result = $mgr.Encrypt($plaintext)
            $prunedKeyId = $result.KeyId
            
            # Prune the key
            Start-Sleep -Milliseconds 10
            $mgr.Rotate()
            Start-Sleep -Milliseconds 10
            $mgr.Rotate()
            
            # ReEncrypt should fail because old key is pruned
            { $mgr.ReEncrypt($prunedKeyId, $result.Ciphertext) } | Should -Throw -ExceptionType ([System.Security.Cryptography.CryptographicException])
        }

        It 'ReEncrypt produces different ciphertext but same plaintext' {
            $mgr = [RotatingKeyManager]::new(3)
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('test message')
            
            $result1 = $mgr.Encrypt($plaintext)
            
            Start-Sleep -Milliseconds 10
            $mgr.Rotate()
            
            $result2 = $mgr.ReEncrypt($result1.KeyId, $result1.Ciphertext)
            
            # Different ciphertext (different key and nonce)
            $result2.Ciphertext | Should -Not -Be $result1.Ciphertext
            
            # Same plaintext
            $decrypted1 = $mgr.Decrypt($result1.KeyId, $result1.Ciphertext)
            $decrypted2 = $mgr.Decrypt($result2.KeyId, $result2.Ciphertext)
            [System.Text.Encoding]::UTF8.GetString($decrypted1) | Should -Be 'test message'
            [System.Text.Encoding]::UTF8.GetString($decrypted2) | Should -Be 'test message'
        }
    }

    Context 'Edge cases' {
        It 'Handles empty plaintext' {
            $mgr = [RotatingKeyManager]::new(3)
            $plaintext = [byte[]]::new(0)
            
            $result = $mgr.Encrypt($plaintext)
            $decrypted = $mgr.Decrypt($result.KeyId, $result.Ciphertext)
            
            $decrypted.Length | Should -Be 0
        }

        It 'Handles large plaintext' {
            $mgr = [RotatingKeyManager]::new(3)
            $plaintext = [byte[]]::new(1MB)
            [System.Security.Cryptography.RandomNumberGenerator]::Fill($plaintext)
            
            $result = $mgr.Encrypt($plaintext)
            $decrypted = $mgr.Decrypt($result.KeyId, $result.Ciphertext)
            
            $decrypted.Length | Should -Be $plaintext.Length
            $decrypted | Should -Be $plaintext
        }

        It 'Generates unique key IDs on each rotation' {
            $mgr = [RotatingKeyManager]::new(10)
            $keyIds = @($mgr.GetCurrentKeyId())
            
            for ($i = 0; $i -lt 9; $i++) {
                Start-Sleep -Milliseconds 10
                $mgr.Rotate()
                $keyIds += $mgr.GetCurrentKeyId()
            }
            
            $uniqueIds = $keyIds | Select-Object -Unique
            $uniqueIds.Count | Should -Be 10
        }
    }
}
