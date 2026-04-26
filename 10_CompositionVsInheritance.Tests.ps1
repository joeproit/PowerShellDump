<#
.SYNOPSIS
    Pester 5.x tests for 10_CompositionVsInheritance.ps1
#>

BeforeAll {
    . $PSScriptRoot/10_CompositionVsInheritance.ps1
}

Describe 'ComposedSecureChannel' {
    Context 'Composition with AesGcmCipher and RsaSigner' {
        BeforeAll {
            $cipher = [AesGcmCipher]::new()
            $signer = [RsaSigner]::new()
            $channel = [ComposedSecureChannel]::new($cipher, $signer, 'peer1')
        }

        It 'should create channel with correct PeerId' {
            $channel.PeerId | Should -Be 'peer1'
        }

        It 'should send and receive message correctly' {
            $message = [System.Text.Encoding]::UTF8.GetBytes('Hello World')
            $packet = $channel.Send($message)
            
            $packet.Sealed | Should -Not -BeNullOrEmpty
            $packet.Signature | Should -Not -BeNullOrEmpty
            $packet.Peer | Should -Be 'peer1'
            
            $received = $channel.Receive($packet)
            $received | Should -Be $message
        }

        It 'should reject packet with invalid signature' {
            $message = [System.Text.Encoding]::UTF8.GetBytes('Test')
            $packet = $channel.Send($message)
            
            # Corrupt the signature
            $packet.Signature[0] = $packet.Signature[0] -bxor 0xFF
            
            { $channel.Receive($packet) } | Should -Throw '*Signature verification failed*'
        }
    }

    Context 'Swapping cipher implementation (AesGcmCipher -> AesCbcCipher)' {
        It 'should work with AesCbcCipher without modifying SecureChannel' {
            $cipher = [AesCbcCipher]::new()
            $signer = [HmacSigner]::new()
            $channel = [ComposedSecureChannel]::new($cipher, $signer, 'peer2')
            
            $message = [System.Text.Encoding]::UTF8.GetBytes('CBC Mode Test')
            $packet = $channel.Send($message)
            
            $packet.Sealed | Should -Not -BeNullOrEmpty
            $packet.Signature | Should -Not -BeNullOrEmpty
            
            $received = $channel.Receive($packet)
            $received | Should -Be $message
        }

        It 'should work with different cipher instances independently' {
            # Channel 1 with GCM
            $gcmCipher = [AesGcmCipher]::new()
            $signer1 = [HmacSigner]::new()
            $channel1 = [ComposedSecureChannel]::new($gcmCipher, $signer1, 'alice')
            
            # Channel 2 with CBC
            $cbcCipher = [AesCbcCipher]::new()
            $signer2 = [HmacSigner]::new()
            $channel2 = [ComposedSecureChannel]::new($cbcCipher, $signer2, 'bob')
            
            $msg1 = [System.Text.Encoding]::UTF8.GetBytes('Message from Alice')
            $msg2 = [System.Text.Encoding]::UTF8.GetBytes('Message from Bob')
            
            $packet1 = $channel1.Send($msg1)
            $packet2 = $channel2.Send($msg2)
            
            $received1 = $channel1.Receive($packet1)
            $received2 = $channel2.Receive($packet2)
            
            $received1 | Should -Be $msg1
            $received2 | Should -Be $msg2
        }
    }

    Context 'Swapping signer implementation (RsaSigner -> HmacSigner)' {
        It 'should work with HmacSigner without modifying SecureChannel' {
            $cipher = [AesGcmCipher]::new()
            $signer = [HmacSigner]::new()
            $channel = [ComposedSecureChannel]::new($cipher, $signer, 'peer3')
            
            $message = [System.Text.Encoding]::UTF8.GetBytes('HMAC signing test')
            $packet = $channel.Send($message)
            
            $received = $channel.Receive($packet)
            $received | Should -Be $message
        }
    }

    Context 'Edge cases' {
        BeforeAll {
            $cipher = [AesGcmCipher]::new()
            $signer = [RsaSigner]::new()
            $channel = [ComposedSecureChannel]::new($cipher, $signer, 'edge-test')
        }

        It 'should handle empty message' {
            $message = [byte[]]@()
            $packet = $channel.Send($message)
            $received = $channel.Receive($packet)
            $received.Length | Should -Be 0
        }

        It 'should handle large message' {
            $message = [byte[]]::new(10000)
            [System.Security.Cryptography.RandomNumberGenerator]::Fill($message)
            $packet = $channel.Send($message)
            $received = $channel.Receive($packet)
            $received | Should -Be $message
        }
    }
}

Describe 'LoggingSecureChannel' {
    Context 'Logging functionality' {
        BeforeAll {
            $cipher = [AesGcmCipher]::new()
            $signer = [HmacSigner]::new()
            $loggingChannel = [LoggingSecureChannel]::new($cipher, $signer, 'logged-peer')
        }

        It 'should log Send operations' {
            $message = [System.Text.Encoding]::UTF8.GetBytes('Test message')
            $packet = $loggingChannel.Send($message)
            
            $log = $loggingChannel.GetLog()
            $log.Count | Should -BeGreaterThan 0
            $log[-1] | Should -Match 'Send: \d+ bytes to logged-peer'
        }

        It 'should log Receive operations' {
            $message = [System.Text.Encoding]::UTF8.GetBytes('Another test')
            $packet = $loggingChannel.Send($message)
            $loggingChannel.Receive($packet)
            
            $log = $loggingChannel.GetLog()
            $log | Where-Object { $_ -match 'Receive:' } | Should -Not -BeNullOrEmpty
        }

        It 'should clear log' {
            $message = [System.Text.Encoding]::UTF8.GetBytes('Clear test')
            $loggingChannel.Send($message)
            
            $loggingChannel.GetLog().Count | Should -BeGreaterThan 0
            
            $loggingChannel.ClearLog()
            $loggingChannel.GetLog().Count | Should -Be 0
        }

        It 'should accumulate multiple operations in log' {
            $loggingChannel.ClearLog()
            
            for ($i = 0; $i -lt 5; $i++) {
                $msg = [System.Text.Encoding]::UTF8.GetBytes("Message $i")
                $packet = $loggingChannel.Send($msg)
                $loggingChannel.Receive($packet)
            }
            
            $log = $loggingChannel.GetLog()
            $log.Count | Should -Be 10  # 5 sends + 5 receives
        }
    }

    Context 'Composition behavior with different ciphers' {
        It 'should work with AesCbcCipher via composition' {
            $cipher = [AesCbcCipher]::new()
            $signer = [HmacSigner]::new()
            $loggingChannel = [LoggingSecureChannel]::new($cipher, $signer, 'cbc-logged')
            
            $message = [System.Text.Encoding]::UTF8.GetBytes('CBC with logging')
            $packet = $loggingChannel.Send($message)
            $received = $loggingChannel.Receive($packet)
            
            $received | Should -Be $message
            $loggingChannel.GetLog().Count | Should -Be 2
        }
    }
}

Describe 'Cipher Implementations' {
    Context 'AesGcmCipher' {
        BeforeAll {
            $cipher = [AesGcmCipher]::new()
        }

        It 'should encrypt and decrypt correctly' {
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('GCM Test Data')
            $ciphertext = $cipher.Seal($plaintext)
            $decrypted = $cipher.Open($ciphertext)
            $decrypted | Should -Be $plaintext
        }

        It 'should produce different ciphertexts for same plaintext (nonce randomization)' {
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('Same message')
            $ct1 = $cipher.Seal($plaintext)
            $ct2 = $cipher.Seal($plaintext)
            $ct1 | Should -Not -Be $ct2
        }
    }

    Context 'AesCbcCipher' {
        BeforeAll {
            $cipher = [AesCbcCipher]::new()
        }

        It 'should encrypt and decrypt correctly' {
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('CBC Test Data')
            $ciphertext = $cipher.Seal($plaintext)
            $decrypted = $cipher.Open($ciphertext)
            $decrypted | Should -Be $plaintext
        }

        It 'should produce different ciphertexts for same plaintext (IV randomization)' {
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('Same message')
            $ct1 = $cipher.Seal($plaintext)
            $ct2 = $cipher.Seal($plaintext)
            $ct1 | Should -Not -Be $ct2
        }
    }
}

Describe 'Signer Implementations' {
    Context 'RsaSigner' {
        BeforeAll {
            $signer = [RsaSigner]::new()
        }

        It 'should sign and verify correctly' {
            $data = [System.Text.Encoding]::UTF8.GetBytes('RSA signing test')
            $signature = $signer.Sign($data)
            $signer.Verify($data, $signature) | Should -Be $true
        }

        It 'should reject invalid signature' {
            $data = [System.Text.Encoding]::UTF8.GetBytes('Data to sign')
            $signature = $signer.Sign($data)
            $signature[0] = $signature[0] -bxor 0xFF
            $signer.Verify($data, $signature) | Should -Be $false
        }

        It 'should reject signature for different data' {
            $data1 = [System.Text.Encoding]::UTF8.GetBytes('Original data')
            $data2 = [System.Text.Encoding]::UTF8.GetBytes('Modified data')
            $signature = $signer.Sign($data1)
            $signer.Verify($data2, $signature) | Should -Be $false
        }
    }

    Context 'HmacSigner' {
        BeforeAll {
            $signer = [HmacSigner]::new()
        }

        It 'should sign and verify correctly' {
            $data = [System.Text.Encoding]::UTF8.GetBytes('HMAC signing test')
            $signature = $signer.Sign($data)
            $signer.Verify($data, $signature) | Should -Be $true
        }

        It 'should reject invalid signature' {
            $data = [System.Text.Encoding]::UTF8.GetBytes('Data to sign')
            $signature = $signer.Sign($data)
            $signature[0] = $signature[0] -bxor 0xFF
            $signer.Verify($data, $signature) | Should -Be $false
        }

        It 'should reject wrong length signature' {
            $data = [System.Text.Encoding]::UTF8.GetBytes('Test data')
            $signature = $signer.Sign($data)
            $wrongLengthSig = $signature[0..15]  # Truncate
            $signer.Verify($data, $wrongLengthSig) | Should -Be $false
        }
    }
}

Describe 'No Direct FIPS Reference (Composition Validation)' {
    It 'should have no hardcoded cipher type in ComposedSecureChannel' {
        $sourceCode = Get-Content $PSScriptRoot/10_CompositionVsInheritance.ps1 -Raw
        # Check that ComposedSecureChannel class doesn't instantiate specific cipher
        $channelClass = $sourceCode -match 'class ComposedSecureChannel\s*\{[^}]+\}'
        $matches[0] | Should -Not -Match 'AesGcmCipher\('
        $matches[0] | Should -Not -Match 'AesCbcCipher\('
        $matches[0] | Should -Not -Match 'new\(\s*\)\s*{' -Because 'Should use injected dependencies'
    }
}
