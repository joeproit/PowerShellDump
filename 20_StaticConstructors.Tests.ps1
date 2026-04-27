BeforeAll {
    . $PSScriptRoot/20_StaticConstructors.ps1
}

Describe 'AlgorithmCatalog Static Constructor' {
    Context 'Static constructor initialization' {
        It 'Fires exactly once on first access' {
            # Access static member to trigger static constructor
            $supported = [AlgorithmCatalog]::Supported
            $initCount1 = [AlgorithmCatalog]::GetInitCount()
            
            # Access again
            $defaultAlgo = [AlgorithmCatalog]::DefaultAlgorithm
            $initCount2 = [AlgorithmCatalog]::GetInitCount()
            
            # Access yet again via method
            $isSupported = [AlgorithmCatalog]::IsSupported('AES-256-GCM')
            $initCount3 = [AlgorithmCatalog]::GetInitCount()
            
            # Should be 1 for all accesses
            $initCount1 | Should -Be 1
            $initCount2 | Should -Be 1
            $initCount3 | Should -Be 1
        }
        
        It 'Initializes Supported HashSet with expected algorithms' {
            $supported = [AlgorithmCatalog]::Supported
            $supported | Should -Not -BeNullOrEmpty
            $supported.Count | Should -Be 4
            $supported.Contains('AES-128-GCM') | Should -Be $true
            $supported.Contains('AES-256-GCM') | Should -Be $true
            $supported.Contains('ChaCha20-Poly1305') | Should -Be $true
            $supported.Contains('AES-256-CBC') | Should -Be $true
        }
        
        It 'Initializes KeySizes Dictionary correctly' {
            [AlgorithmCatalog]::KeySizes['AES-128-GCM'] | Should -Be 128
            [AlgorithmCatalog]::KeySizes['AES-256-GCM'] | Should -Be 256
            [AlgorithmCatalog]::KeySizes['ChaCha20-Poly1305'] | Should -Be 256
            [AlgorithmCatalog]::KeySizes['AES-256-CBC'] | Should -Be 256
        }
        
        It 'Sets DefaultAlgorithm to AES-256-GCM' {
            [AlgorithmCatalog]::DefaultAlgorithm | Should -Be 'AES-256-GCM'
        }
    }
    
    Context 'GetKeySize method' {
        It 'Returns correct key size for known algorithms' {
            [AlgorithmCatalog]::GetKeySize('AES-128-GCM') | Should -Be 128
            [AlgorithmCatalog]::GetKeySize('AES-256-GCM') | Should -Be 256
            [AlgorithmCatalog]::GetKeySize('ChaCha20-Poly1305') | Should -Be 256
            [AlgorithmCatalog]::GetKeySize('AES-256-CBC') | Should -Be 256
        }
        
        It 'Is case-insensitive for algorithm names' {
            [AlgorithmCatalog]::GetKeySize('aes-256-gcm') | Should -Be 256
            [AlgorithmCatalog]::GetKeySize('AES-256-GCM') | Should -Be 256
            [AlgorithmCatalog]::GetKeySize('Aes-256-Gcm') | Should -Be 256
        }
        
        It 'Throws ArgumentException for unknown algorithm' {
            { [AlgorithmCatalog]::GetKeySize('UNKNOWN-ALGO') } | 
                Should -Throw -ExceptionType ([System.ArgumentException])
        }
        
        It 'Throws with meaningful error message for unknown algorithm' {
            { [AlgorithmCatalog]::GetKeySize('RSA-2048') } | 
                Should -Throw -ExpectedMessage '*Unknown algorithm: RSA-2048*'
        }
        
        It 'Throws for null or empty algorithm name' {
            { [AlgorithmCatalog]::GetKeySize('') } | 
                Should -Throw -ExceptionType ([System.ArgumentException])
        }
    }
    
    Context 'IsSupported method' {
        It 'Returns true for supported algorithms' {
            [AlgorithmCatalog]::IsSupported('AES-128-GCM') | Should -Be $true
            [AlgorithmCatalog]::IsSupported('AES-256-GCM') | Should -Be $true
            [AlgorithmCatalog]::IsSupported('ChaCha20-Poly1305') | Should -Be $true
            [AlgorithmCatalog]::IsSupported('AES-256-CBC') | Should -Be $true
        }
        
        It 'Returns false for unsupported algorithms' {
            [AlgorithmCatalog]::IsSupported('RSA-2048') | Should -Be $false
            [AlgorithmCatalog]::IsSupported('DES-CBC') | Should -Be $false
            [AlgorithmCatalog]::IsSupported('UNKNOWN') | Should -Be $false
        }
        
        It 'Is case-insensitive' {
            [AlgorithmCatalog]::IsSupported('aes-256-gcm') | Should -Be $true
            [AlgorithmCatalog]::IsSupported('CHACHA20-POLY1305') | Should -Be $true
        }
    }
    
    Context 'Refresh method' {
        It 'Re-runs initialization when called' {
            $beforeRefresh = [AlgorithmCatalog]::GetInitCount()
            
            [AlgorithmCatalog]::Refresh()
            
            $afterRefresh = [AlgorithmCatalog]::GetInitCount()
            $afterRefresh | Should -Be ($beforeRefresh + 1)
        }
        
        It 'Maintains algorithm catalog after refresh' {
            [AlgorithmCatalog]::Refresh()
            
            [AlgorithmCatalog]::IsSupported('AES-256-GCM') | Should -Be $true
            [AlgorithmCatalog]::GetKeySize('AES-256-GCM') | Should -Be 256
            [AlgorithmCatalog]::DefaultAlgorithm | Should -Be 'AES-256-GCM'
        }
        
        It 'Can be called multiple times' {
            $beforeCount = [AlgorithmCatalog]::GetInitCount()
            
            [AlgorithmCatalog]::Refresh()
            [AlgorithmCatalog]::Refresh()
            [AlgorithmCatalog]::Refresh()
            
            $afterCount = [AlgorithmCatalog]::GetInitCount()
            $afterCount | Should -Be ($beforeCount + 3)
        }
    }
}
