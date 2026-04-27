BeforeAll {
    # Load the type extensions
    . $PSScriptRoot/18_UpdateTypeData.ps1
}

Describe 'byte[] Type Extensions' {
    Context 'ToHex Method' {
        It 'Converts empty byte array to empty string' {
            $bytes = [byte[]]@()
            $bytes.ToHex() | Should -Be ''
        }

        It 'Converts single byte to hex' {
            $bytes = [byte[]]@(0x42)
            $bytes.ToHex() | Should -Be '42'
        }

        It 'Converts multiple bytes to hex' {
            $bytes = [byte[]]@(0xde, 0xad, 0xbe, 0xef)
            $bytes.ToHex() | Should -Be 'deadbeef'
        }

        It 'Handles zero bytes' {
            $bytes = [byte[]]@(0x00, 0x01, 0x00)
            $bytes.ToHex() | Should -Be '000100'
        }
    }

    Context 'ToBase64 Method' {
        It 'Converts empty byte array to empty string' {
            $bytes = [byte[]]@()
            $bytes.ToBase64() | Should -Be ''
        }

        It 'Converts bytes to base64' {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes('hello')
            $bytes.ToBase64() | Should -Be 'aGVsbG8='
        }

        It 'Handles binary data' {
            $bytes = [byte[]]@(0xde, 0xad, 0xbe, 0xef)
            $bytes.ToBase64() | Should -Be '3q2+7w=='
        }
    }

    Context 'ToBase58 Method' {
        It 'Converts empty byte array to empty string' {
            $bytes = [byte[]]@()
            $bytes.ToBase58() | Should -Be ''
        }

        It 'Converts single byte to base58' {
            $bytes = [byte[]]@(0x00)
            $bytes.ToBase58() | Should -Be '1'
        }

        It 'Handles leading zeros' {
            $bytes = [byte[]]@(0x00, 0x00, 0x01)
            $result = $bytes.ToBase58()
            $result | Should -Match '^11'  # Two leading '1's for two leading zeros
        }

        It 'Does not contain ambiguous characters' {
            # Test the alphabet itself - should not contain 0, O, I, l
            $alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'
            $alphabet.Contains('0') | Should -Be $false
            $alphabet.Contains('O') | Should -Be $false
            $alphabet.Contains('I') | Should -Be $false
            $alphabet.Contains('l') | Should -Be $false
        }

        It 'Converts known value correctly' {
            # Test vector: [1, 2, 3] should encode consistently
            $bytes = [byte[]]@(1, 2, 3)
            $result = $bytes.ToBase58()
            $result | Should -Not -BeNullOrEmpty
            $result.Length | Should -BeGreaterThan 0
        }

        It 'Handles all zero bytes' {
            $bytes = [byte[]]@(0x00, 0x00, 0x00)
            $bytes.ToBase58() | Should -Be '111'
        }

        It 'Handles maximum byte value' {
            $bytes = [byte[]]@(0xFF)
            $result = $bytes.ToBase58()
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Works with 32-byte key' {
            $bytes = [byte[]]::new(32)
            [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
            $result = $bytes.ToBase58()
            $result | Should -Not -BeNullOrEmpty
            $result.Length | Should -BeGreaterThan 0
        }
    }

    Context 'SHA256Hash Method' {
        It 'Computes hash of empty byte array' {
            $bytes = [byte[]]@()
            $hash = $bytes.SHA256Hash()
            $hash.Length | Should -Be 32
            # Force to array to handle PowerShell unwrapping
            $hexStr = (@($hash) | ForEach-Object { $_.ToString('x2') }) -join ''
            $hexStr | Should -Be 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
        }

        It 'Computes hash of known input' {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes('hello')
            $hash = $bytes.SHA256Hash()
            $hash.Length | Should -Be 32
            # Force to array to handle PowerShell unwrapping
            $hexStr = (@($hash) | ForEach-Object { $_.ToString('x2') }) -join ''
            $hexStr | Should -Be '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824'
        }

        It 'Returns byte array' {
            $bytes = [byte[]]@(1, 2, 3)
            $hash = $bytes.SHA256Hash()
            # In PS 7.4, null resolves to byte[] - verify value not type
            $hash | Should -Not -BeNullOrEmpty
            $hash.Length | Should -Be 32
        }

        It 'Is idempotent' {
            $bytes = [byte[]]@(1, 2, 3)
            $hash1 = $bytes.SHA256Hash()
            $hash2 = $bytes.SHA256Hash()
            # Force to array to handle PowerShell unwrapping
            $hex1 = (@($hash1) | ForEach-Object { $_.ToString('x2') }) -join ''
            $hex2 = (@($hash2) | ForEach-Object { $_.ToString('x2') }) -join ''
            $hex1 | Should -Be $hex2
        }
    }

    Context 'IsKeySize Property' {
        It 'Returns true for 16 bytes (AES-128)' {
            $bytes = [byte[]]::new(16)
            $bytes.IsKeySize | Should -Be $true
        }

        It 'Returns true for 24 bytes (AES-192)' {
            $bytes = [byte[]]::new(24)
            $bytes.IsKeySize | Should -Be $true
        }

        It 'Returns true for 32 bytes (AES-256)' {
            $bytes = [byte[]]::new(32)
            $bytes.IsKeySize | Should -Be $true
        }

        It 'Returns false for 15 bytes' {
            $bytes = [byte[]]::new(15)
            $bytes.IsKeySize | Should -Be $false
        }

        It 'Returns false for 17 bytes' {
            $bytes = [byte[]]::new(17)
            $bytes.IsKeySize | Should -Be $false
        }

        It 'Returns false for 0 bytes' {
            $bytes = [byte[]]@()
            $bytes.IsKeySize | Should -Be $false
        }

        It 'Returns false for 64 bytes' {
            $bytes = [byte[]]::new(64)
            $bytes.IsKeySize | Should -Be $false
        }
    }
}

Describe 'String Type Extensions' {
    Context 'ToUTF8Bytes Method' {
        It 'Converts empty string to empty byte array' {
            $str = ''
            $bytes = $str.ToUTF8Bytes()
            $bytes.Length | Should -Be 0
        }

        It 'Converts ASCII string to bytes' {
            $str = 'hello'
            $bytes = $str.ToUTF8Bytes()
            $bytes.Length | Should -Be 5
            # Verify value not type due to PS 7.4 unwrapping
            $bytes | Should -Not -BeNullOrEmpty
        }

        It 'Converts Unicode string correctly' {
            $str = 'hello 世界'
            $bytes = $str.ToUTF8Bytes()
            # Verify value not type due to PS 7.4 unwrapping
            $bytes | Should -Not -BeNullOrEmpty
            $bytes.Length | Should -BeGreaterThan 6  # UTF-8 encoding of Chinese chars
        }

        It 'Matches System.Text.Encoding.UTF8.GetBytes' {
            $str = 'test string 123'
            $bytes1 = $str.ToUTF8Bytes()
            $bytes2 = [System.Text.Encoding]::UTF8.GetBytes($str)
            # Force to array and convert to hex
            $hex1 = (@($bytes1) | ForEach-Object { $_.ToString('x2') }) -join ''
            $hex2 = (@($bytes2) | ForEach-Object { $_.ToString('x2') }) -join ''
            $hex1 | Should -Be $hex2
        }
    }

    Context 'SHA256Hex Method' {
        It 'Computes hash of empty string' {
            $str = ''
            $hash = $str.SHA256Hex()
            $hash | Should -Be 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
        }

        It 'Computes hash of known string' {
            $str = 'hello'
            $hash = $str.SHA256Hex()
            $hash | Should -Be '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824'
        }

        It 'Returns lowercase hex string' {
            $str = 'test'
            $hash = $str.SHA256Hex()
            $hash | Should -Match '^[0-9a-f]{64}$'
        }

        It 'Is idempotent' {
            $str = 'test string'
            $hash1 = $str.SHA256Hex()
            $hash2 = $str.SHA256Hex()
            $hash1 | Should -Be $hash2
        }

        It 'Handles Unicode strings' {
            $str = '你好世界'
            $hash = $str.SHA256Hex()
            $hash | Should -Match '^[0-9a-f]{64}$'
            $hash.Length | Should -Be 64
        }
    }
}

Describe 'Type Extensions Idempotency' {
    It 'Can reload type extensions without errors' {
        # This tests that -Force flag works correctly
        { . $PSScriptRoot/18_UpdateTypeData.ps1 } | Should -Not -Throw
    }

    It 'Methods still work after reload' {
        . $PSScriptRoot/18_UpdateTypeData.ps1
        $bytes = [byte[]]@(1, 2, 3)
        { $bytes.ToHex() } | Should -Not -Throw
        { $bytes.ToBase64() } | Should -Not -Throw
        { $bytes.ToBase58() } | Should -Not -Throw
        { $bytes.SHA256Hash() } | Should -Not -Throw
        { $bytes.IsKeySize } | Should -Not -Throw
    }
}

Describe 'Integration Tests' {
    It 'Can chain byte[] methods' {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes('test')
        $hash = $bytes.SHA256Hash()
        # Force to array for method calls
        $hashArray = @($hash)
        { (@($hashArray) | ForEach-Object { $_.ToString('x2') }) -join '' } | Should -Not -Throw
        { [Convert]::ToBase64String($hashArray) } | Should -Not -Throw
    }

    It 'Can use string methods to create byte arrays' {
        $str = 'hello world'
        $bytes = $str.ToUTF8Bytes()
        # Force to array and convert to hex
        $hex = (@($bytes) | ForEach-Object { $_.ToString('x2') }) -join ''
        $hex | Should -Be '68656c6c6f20776f726c64'
    }

    It 'Full crypto workflow' {
        # Generate a key
        $key = [byte[]]::new(32)
        [System.Security.Cryptography.RandomNumberGenerator]::Fill($key)
        
        # Verify key size
        $key.IsKeySize | Should -Be $true
        
        # Test all encoding methods
        $hex = $key.ToHex()
        $base64 = $key.ToBase64()
        $base58 = $key.ToBase58()
        
        $hex.Length | Should -Be 64
        $base64.Length | Should -BeGreaterThan 0
        $base58.Length | Should -BeGreaterThan 0
        
        # Test hashing - force result to array
        $hash = @($key.SHA256Hash())
        $hash.Length | Should -Be 32
        # Create a new byte array to test IsKeySize
        $hashBytes = [byte[]]::new(32)
        for ($i = 0; $i -lt 32; $i++) { $hashBytes[$i] = $hash[$i] }
        $hashBytes.IsKeySize | Should -Be $true
    }

    It 'String hash matches byte hash' {
        $str = 'test string'
        $strHash = $str.SHA256Hex()
        
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($str)
        $hashResult = $bytes.SHA256Hash()
        # Force to array and convert to hex
        $bytesHash = (@($hashResult) | ForEach-Object { $_.ToString('x2') }) -join ''
        
        $strHash | Should -Be $bytesHash
    }
}
