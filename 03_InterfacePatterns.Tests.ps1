<#
.SYNOPSIS
    Pester 5.x tests for 03_InterfacePatterns.ps1
.DESCRIPTION
    Validates:
    - IDisposable two-phase dispose (multiple calls safe)
    - IComparable sorting behavior on CryptoKey
    - ICloneable implementation on CryptoKey
    - ICryptoTransform contract enforcement
    - XorTransform and Base64Transform implementations
#>

BeforeAll {
    # Source the main file (includes test stub classes)
    . $PSScriptRoot/03_InterfacePatterns.ps1
}



Describe "ManagedCryptoService - IDisposable Pattern" {
    
    It "Should create and dispose successfully" {
        $svc = [ManagedCryptoService]::new()
        { $svc.Dispose() } | Should -Not -Throw
    }

    It "Should allow Dispose() to be called twice without throwing" {
        $svc = [ManagedCryptoService]::new()
        $svc.Dispose()
        { $svc.Dispose() } | Should -Not -Throw
    }

    It "Should throw ObjectDisposedException when using after Dispose()" {
        $svc = [ManagedCryptoService]::new()
        $svc.Dispose()
        $testData = [byte[]]@(1, 2, 3, 4)
        { $svc.Encrypt($testData) } | Should -Throw -ExceptionType ([System.ObjectDisposedException])
    }

    It "Should encrypt data before disposal" {
        $svc = [ManagedCryptoService]::new()
        $testData = [byte[]]@(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16)
        $encrypted = $svc.Encrypt($testData)
        $encrypted | Should -Not -BeNullOrEmpty
        $encrypted.Length | Should -BeGreaterThan 0
        $svc.Dispose()
    }

    It "Should implement System.IDisposable interface" {
        $svc = [ManagedCryptoService]::new()
        $svc -is [System.IDisposable] | Should -Be $true
        $svc.Dispose()
    }
}

Describe "CryptoKey - IComparable Implementation" {
    
    It "Should sort keys by expiry date ascending" {
        $keyA = [CryptoKey]::new('alpha', 90)
        $keyB = [CryptoKey]::new('beta', 30)
        $keyC = [CryptoKey]::new('gamma', 365)
        
        $keys = @($keyA, $keyB, $keyC)
        $sorted = $keys | Sort-Object
        
        $sorted[0].Id | Should -Be 'beta'
        $sorted[1].Id | Should -Be 'alpha'
        $sorted[2].Id | Should -Be 'gamma'
    }

    It "Should compare two keys correctly" {
        $key1 = [CryptoKey]::new('first', 30)
        $key2 = [CryptoKey]::new('second', 60)
        
        $result = $key1.CompareTo($key2)
        $result | Should -BeLessThan 0
    }

    It "Should return 1 when comparing to non-CryptoKey object" {
        $key = [CryptoKey]::new('test', 30)
        $result = $key.CompareTo("not a key")
        $result | Should -Be 1
    }

    It "Should implement System.IComparable interface" {
        $key = [CryptoKey]::new('test', 30)
        $key -is [System.IComparable] | Should -Be $true
    }
}

Describe "CryptoKey - ICloneable Implementation" {
    
    It "Should implement System.ICloneable interface" {
        $key = [CryptoKey]::new('original', 90)
        $key -is [System.ICloneable] | Should -Be $true
    }

    It "Should create a clone with same property values" {
        $original = [CryptoKey]::new('original', 90)
        $clone = $original.Clone()
        
        $clone.Id | Should -Be $original.Id
        $clone.Created | Should -Be $original.Created
        $clone.Expires | Should -Be $original.Expires
    }

    It "Should create a distinct object (not reference)" {
        $original = [CryptoKey]::new('original', 90)
        $clone = $original.Clone()
        
        [Object]::ReferenceEquals($original, $clone) | Should -Be $false
    }

    It "Should allow independent modification of clone" {
        $original = [CryptoKey]::new('original', 90)
        $clone = $original.Clone()
        
        $clone.Id = 'modified'
        $clone.Id | Should -Be 'modified'
        $original.Id | Should -Be 'original'
    }

    It "Clone should be of type CryptoKey" {
        $original = [CryptoKey]::new('original', 90)
        $clone = $original.Clone()
        
        $clone | Should -BeOfType ([CryptoKey])
    }
}

Describe "ICryptoTransform - Contract Validation" {
    
    It "Should validate XorTransform successfully" {
        $xor = [XorTransform]::new(42)
        { [ICryptoTransform]::Validate($xor) } | Should -Not -Throw
    }

    It "Should throw InvalidOperationException for incomplete implementation" {
        $stub = [IncompleteTransform]::new()
        { [ICryptoTransform]::Validate($stub) } | Should -Throw -ExceptionType ([System.InvalidOperationException])
    }

    It "Should throw with correct error message for missing Transform" {
        $stub = [NoTransform]::new()
        { [ICryptoTransform]::Validate($stub) } | Should -Throw "*must implement Transform*"
    }

    It "Should throw with correct error message for missing InverseTransform" {
        $stub = [NoInverse]::new()
        { [ICryptoTransform]::Validate($stub) } | Should -Throw "*must implement InverseTransform*"
    }

    It "Should throw with correct error message for missing GetAlgorithmId" {
        $stub = [NoAlgorithmId]::new()
        { [ICryptoTransform]::Validate($stub) } | Should -Throw "*must implement GetAlgorithmId*"
    }
}

Describe "XorTransform - Concrete Implementation" {
    
    It "Should transform data with XOR" {
        $xor = [XorTransform]::new(0x5A)
        $input = [byte[]]@(0x00, 0xFF, 0x55, 0xAA)
        
        $transformed = $xor.Transform($input)
        $transformed[0] | Should -Be 0x5A
        $transformed[1] | Should -Be 0xA5
        $transformed[2] | Should -Be 0x0F
        $transformed[3] | Should -Be 0xF0
    }

    It "Should be self-inverse (Transform = InverseTransform)" {
        $xor = [XorTransform]::new(0x3C)
        $input = [byte[]]@(1, 2, 3, 4, 5)
        
        $transformed = $xor.Transform($input)
        $restored = $xor.InverseTransform($transformed)
        
        $restored.Length | Should -Be $input.Length
        for ($i = 0; $i -lt $input.Length; $i++) {
            $restored[$i] | Should -Be $input[$i]
        }
    }

    It "Should return correct algorithm ID" {
        $xor = [XorTransform]::new(1)
        $xor.GetAlgorithmId() | Should -Be "XOR-1"
    }

    It "Should inherit from ICryptoTransform" {
        $xor = [XorTransform]::new(1)
        $xor -is [ICryptoTransform] | Should -Be $true
    }
}

Describe "Base64Transform - Agent Task Implementation" {
    
    It "Should create Base64Transform instance" {
        $b64 = [Base64Transform]::new()
        $b64 | Should -Not -BeNullOrEmpty
    }

    It "Should inherit from ICryptoTransform" {
        $b64 = [Base64Transform]::new()
        $b64 -is [ICryptoTransform] | Should -Be $true
    }

    It "Should pass ICryptoTransform.Validate()" {
        $b64 = [Base64Transform]::new()
        { [ICryptoTransform]::Validate($b64) } | Should -Not -Throw
    }

    It "Should return correct algorithm ID" {
        $b64 = [Base64Transform]::new()
        $b64.GetAlgorithmId() | Should -Be "BASE64-1"
    }

    It "Should transform bytes to base64 encoded UTF8 bytes" {
        $b64 = [Base64Transform]::new()
        $input = [byte[]]@(72, 101, 108, 108, 111)  # "Hello"
        
        $transformed = $b64.Transform($input)
        $base64String = [System.Text.Encoding]::UTF8.GetString($transformed)
        $base64String | Should -Be "SGVsbG8="
    }

    It "Should inverse transform back to original bytes" {
        $b64 = [Base64Transform]::new()
        $input = [byte[]]@(72, 101, 108, 108, 111)  # "Hello"
        
        $transformed = $b64.Transform($input)
        $restored = $b64.InverseTransform($transformed)
        
        $restored.Length | Should -Be $input.Length
        for ($i = 0; $i -lt $input.Length; $i++) {
            $restored[$i] | Should -Be $input[$i]
        }
    }

    It "Should handle empty byte array" {
        $b64 = [Base64Transform]::new()
        $input = [byte[]]@()
        
        $transformed = $b64.Transform($input)
        $restored = $b64.InverseTransform($transformed)
        
        $restored.Length | Should -Be 0
    }

    It "Should handle arbitrary binary data" {
        $b64 = [Base64Transform]::new()
        $input = [byte[]]@(0x00, 0xFF, 0x55, 0xAA, 0x12, 0x34, 0x56, 0x78)
        
        $transformed = $b64.Transform($input)
        $restored = $b64.InverseTransform($transformed)
        
        $restored.Length | Should -Be $input.Length
        for ($i = 0; $i -lt $input.Length; $i++) {
            $restored[$i] | Should -Be $input[$i]
        }
    }
}

Describe "Integration - Multiple Interface Implementations" {
    
    It "Should have CryptoKey implementing both IComparable and ICloneable" {
        $key = [CryptoKey]::new('multi', 60)
        
        $key -is [System.IComparable] | Should -Be $true
        $key -is [System.ICloneable] | Should -Be $true
    }

    It "Should sort cloned keys correctly" {
        $key1 = [CryptoKey]::new('first', 90)
        $key2 = [CryptoKey]::new('second', 30)
        
        $clone1 = $key1.Clone()
        $clone2 = $key2.Clone()
        
        $sorted = @($clone1, $clone2) | Sort-Object
        $sorted[0].Id | Should -Be 'second'
        $sorted[1].Id | Should -Be 'first'
    }

    It "Should validate both XorTransform and Base64Transform" {
        $xor = [XorTransform]::new(42)
        $b64 = [Base64Transform]::new()
        
        { [ICryptoTransform]::Validate($xor) } | Should -Not -Throw
        { [ICryptoTransform]::Validate($b64) } | Should -Not -Throw
    }

    It "Should use both transforms in sequence" {
        $xor = [XorTransform]::new(0x42)
        $b64 = [Base64Transform]::new()
        $input = [byte[]]@(1, 2, 3, 4, 5)
        
        # XOR first, then Base64
        $xored = $xor.Transform($input)
        $encoded = $b64.Transform($xored)
        
        # Reverse: Base64 first, then XOR
        $decoded = $b64.InverseTransform($encoded)
        $restored = $xor.InverseTransform($decoded)
        
        $restored.Length | Should -Be $input.Length
        for ($i = 0; $i -lt $input.Length; $i++) {
            $restored[$i] | Should -Be $input[$i]
        }
    }
}
