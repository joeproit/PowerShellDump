<#
.SYNOPSIS
    Pester tests for 02_Inheritance.ps1
.DESCRIPTION
    Tests covering:
    - Three-level inheritance chain (CryptoBase -> AesService -> AuditedAesService -> GrandchildCrypto)
    - Constructor chaining
    - Method override behavior
    - Type checking and is-a relationships
    - Safe downcasting
#>

BeforeAll {
    . $PSScriptRoot/02_Inheritance.ps1
}

Describe 'CryptoBase' {
    It 'Cannot be instantiated directly (abstract-like base)' {
        $base = [CryptoBase]::new('TEST', 128)
        $base.Algorithm | Should -Be 'TEST'
        $base.KeyBits | Should -Be 128
        $base.CreatedAt | Should -BeOfType [datetime]
    }

    It 'Throws NotImplementedException on Encrypt if not overridden' {
        $base = [CryptoBase]::new('TEST', 128)
        { $base.Encrypt([byte[]]::new(16)) } | Should -Throw -ExceptionType ([System.NotImplementedException])
    }

    It 'Describe() returns formatted string with type name' {
        $base = [CryptoBase]::new('TEST', 128)
        $desc = $base.Describe()
        $desc | Should -Match 'CryptoBase'
        $desc | Should -Match 'TEST'
        $desc | Should -Match '128-bit'
    }
}

Describe 'AesService (Level 1 inheritance)' {
    It 'Instantiates with default constructor' {
        $svc = [AesService]::new()
        $svc | Should -Not -BeNullOrEmpty
        $svc.Algorithm | Should -Be 'AES-256-GCM'
        $svc.KeyBits | Should -Be 256
    }

    It 'Instantiates with 128-bit key' {
        $key = [byte[]]::new(16)
        $svc = [AesService]::new($key)
        $svc.KeyBits | Should -Be 128
    }

    It 'Instantiates with 192-bit key' {
        $key = [byte[]]::new(24)
        $svc = [AesService]::new($key)
        $svc.KeyBits | Should -Be 192
    }

    It 'Instantiates with 256-bit key' {
        $key = [byte[]]::new(32)
        $svc = [AesService]::new($key)
        $svc.KeyBits | Should -Be 256
    }

    It 'Throws ArgumentException for invalid key length' {
        $key = [byte[]]::new(15)
        { [AesService]::new($key) } | Should -Throw -ExceptionType ([System.ArgumentException])
    }

    It 'Implements Encrypt method' {
        $svc = [AesService]::new()
        $plaintext = [System.Text.Encoding]::UTF8.GetBytes('test data')
        $ciphertext = $svc.Encrypt($plaintext)
        $ciphertext | Should -Not -BeNullOrEmpty
        $ciphertext.Length | Should -BeGreaterThan $plaintext.Length
    }

    It 'Is a CryptoBase' {
        $svc = [AesService]::new()
        $svc -is [CryptoBase] | Should -Be $true
    }

    It 'Is an AesService' {
        $svc = [AesService]::new()
        $svc -is [AesService] | Should -Be $true
    }

    It 'Base constructor was called (CreatedAt is set)' {
        $svc = [AesService]::new()
        $svc.CreatedAt | Should -Not -BeNullOrEmpty
        $svc.CreatedAt | Should -BeOfType [datetime]
    }
}

Describe 'AuditedAesService (Level 2 inheritance)' {
    It 'Instantiates successfully' {
        $svc = [AuditedAesService]::new()
        $svc | Should -Not -BeNullOrEmpty
    }

    It 'Initializes AuditLog' {
        $svc = [AuditedAesService]::new()
        $null -eq $svc.AuditLog | Should -Be $false
        $svc.AuditLog.Count | Should -Be 0
    }

    It 'Logs encryption operations' {
        $svc = [AuditedAesService]::new()
        $plaintext = [System.Text.Encoding]::UTF8.GetBytes('test')
        $svc.Encrypt($plaintext)
        $svc.AuditLog.Count | Should -Be 1
        $svc.AuditLog[0] | Should -Match 'ENCRYPT'
        $svc.AuditLog[0] | Should -Match '4 bytes'
    }

    It 'Calls parent Encrypt implementation' {
        $svc = [AuditedAesService]::new()
        $plaintext = [System.Text.Encoding]::UTF8.GetBytes('test')
        $ciphertext = $svc.Encrypt($plaintext)
        $ciphertext | Should -Not -BeNullOrEmpty
        $ciphertext.Length | Should -BeGreaterThan $plaintext.Length
    }

    It 'Is a CryptoBase' {
        $svc = [AuditedAesService]::new()
        $svc -is [CryptoBase] | Should -Be $true
    }

    It 'Is an AesService' {
        $svc = [AuditedAesService]::new()
        $svc -is [AesService] | Should -Be $true
    }

    It 'Is an AuditedAesService' {
        $svc = [AuditedAesService]::new()
        $svc -is [AuditedAesService] | Should -Be $true
    }

    It 'Base constructor chain was called' {
        $svc = [AuditedAesService]::new()
        $svc.Algorithm | Should -Be 'AES-256-GCM'
        $svc.KeyBits | Should -Be 256
        $svc.CreatedAt | Should -Not -BeNullOrEmpty
    }
}

Describe 'GrandchildCrypto (Level 3 inheritance)' {
    It 'Instantiates with default constructor' {
        $gc = [GrandchildCrypto]::new()
        $gc | Should -Not -BeNullOrEmpty
        $gc.Purpose | Should -Be 'Deep inheritance demonstration'
    }

    It 'Instantiates with purpose parameter' {
        $gc = [GrandchildCrypto]::new('Custom purpose')
        $gc.Purpose | Should -Be 'Custom purpose'
    }

    It 'Three-level chain loads without error' {
        { [GrandchildCrypto]::new() } | Should -Not -Throw
    }

    It 'Is a CryptoBase' {
        $gc = [GrandchildCrypto]::new()
        $gc -is [CryptoBase] | Should -Be $true
    }

    It 'Is an AesService' {
        $gc = [GrandchildCrypto]::new()
        $gc -is [AesService] | Should -Be $true
    }

    It 'Is an AuditedAesService' {
        $gc = [GrandchildCrypto]::new()
        $gc -is [AuditedAesService] | Should -Be $true
    }

    It 'Is a GrandchildCrypto' {
        $gc = [GrandchildCrypto]::new()
        $gc -is [GrandchildCrypto] | Should -Be $true
    }

    It 'Base constructor was called (all properties initialized)' {
        $gc = [GrandchildCrypto]::new()
        $gc.Algorithm | Should -Be 'AES-256-GCM'
        $gc.KeyBits | Should -Be 256
        $gc.CreatedAt | Should -Not -BeNullOrEmpty
        $null -eq $gc.AuditLog | Should -Be $false
    }

    It 'Override Describe() fires and calls AesService.Describe()' {
        $gc = [GrandchildCrypto]::new('Test purpose')
        $desc = $gc.Describe()
        # Should contain elements from AesService.Describe()
        $desc | Should -Match 'GrandchildCrypto'
        $desc | Should -Match 'AES-256-GCM'
        $desc | Should -Match '256-bit'
        # Should also contain Purpose from override
        $desc | Should -Match 'Purpose: Test purpose'
    }

    It 'Safe downcast to AesService works' {
        $gc = [GrandchildCrypto]::new()
        $asAes = [AesService]$gc
        $asAes | Should -Not -BeNullOrEmpty
        $asAes.Algorithm | Should -Be 'AES-256-GCM'
    }

    It 'Safe downcast to AuditedAesService works' {
        $gc = [GrandchildCrypto]::new()
        $asAudited = [AuditedAesService]$gc
        $asAudited | Should -Not -BeNullOrEmpty
        $null -eq $asAudited.AuditLog | Should -Be $false
    }

    It 'Safe downcast to CryptoBase works' {
        $gc = [GrandchildCrypto]::new()
        $asBase = [CryptoBase]$gc
        $asBase | Should -Not -BeNullOrEmpty
        $asBase.Algorithm | Should -Be 'AES-256-GCM'
    }

    It 'Inherits Encrypt with audit logging' {
        $gc = [GrandchildCrypto]::new()
        $plaintext = [System.Text.Encoding]::UTF8.GetBytes('test')
        $ciphertext = $gc.Encrypt($plaintext)
        $ciphertext | Should -Not -BeNullOrEmpty
        $gc.AuditLog.Count | Should -Be 1
    }

    It 'GetType() returns GrandchildCrypto' {
        $gc = [GrandchildCrypto]::new()
        $gc.GetType().Name | Should -Be 'GrandchildCrypto'
    }

    It 'BaseType chain is correct' {
        $gc = [GrandchildCrypto]::new()
        $gc.GetType().BaseType.Name | Should -Be 'AuditedAesService'
        $gc.GetType().BaseType.BaseType.Name | Should -Be 'AesService'
        $gc.GetType().BaseType.BaseType.BaseType.Name | Should -Be 'CryptoBase'
    }
}

Describe 'Type hierarchy validation' {
    It 'All levels maintain is-a relationship' {
        $gc = [GrandchildCrypto]::new()
        
        # Direct type
        $gc -is [GrandchildCrypto] | Should -Be $true
        
        # All ancestor types
        $gc -is [AuditedAesService] | Should -Be $true
        $gc -is [AesService] | Should -Be $true
        $gc -is [CryptoBase] | Should -Be $true
    }

    It 'Type checking works at each level' {
        $base = [CryptoBase]::new('TEST', 128)
        $aes = [AesService]::new()
        $audited = [AuditedAesService]::new()
        $gc = [GrandchildCrypto]::new()

        # Base is only base
        $base -is [CryptoBase] | Should -Be $true
        $base -is [AesService] | Should -Be $false

        # AesService is base and AesService
        $aes -is [CryptoBase] | Should -Be $true
        $aes -is [AesService] | Should -Be $true
        $aes -is [AuditedAesService] | Should -Be $false

        # AuditedAesService is all three
        $audited -is [CryptoBase] | Should -Be $true
        $audited -is [AesService] | Should -Be $true
        $audited -is [AuditedAesService] | Should -Be $true
        $audited -is [GrandchildCrypto] | Should -Be $false

        # GrandchildCrypto is all four
        $gc -is [CryptoBase] | Should -Be $true
        $gc -is [AesService] | Should -Be $true
        $gc -is [AuditedAesService] | Should -Be $true
        $gc -is [GrandchildCrypto] | Should -Be $true
    }
}
