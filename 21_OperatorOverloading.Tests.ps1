BeforeAll {
    . "$PSScriptRoot/21_OperatorOverloading.ps1"
}

Describe "CryptoKeyPair Operator Overloading" {
    Context "IEquatable Implementation" {
        It "Should return true when KeyIds match" {
            $k1 = [CryptoKeyPair]::new("key-001", 256, 30)
            $k2 = [CryptoKeyPair]::new("key-001", 128, 15)
            
            $k1 -eq $k2 | Should -Be $true
        }

        It "Should return false when KeyIds differ" {
            $k1 = [CryptoKeyPair]::new("key-001", 256, 30)
            $k2 = [CryptoKeyPair]::new("key-002", 256, 30)
            
            $k1 -eq $k2 | Should -Be $false
        }

        It "Should return false when comparing to null" {
            $k1 = [CryptoKeyPair]::new("key-001", 256, 30)
            
            $k1 -eq $null | Should -Be $false
        }

        It "Should return false when comparing to non-CryptoKeyPair object" {
            $k1 = [CryptoKeyPair]::new("key-001", 256, 30)
            
            $k1.Equals("key-001") | Should -Be $false
        }
    }

    Context "IComparable Implementation" {
        It "Should sort by expiry date using Sort-Object" {
            $k1 = [CryptoKeyPair]::new("key-001", 256, 10)
            $k2 = [CryptoKeyPair]::new("key-002", 128, 20)
            $k3 = [CryptoKeyPair]::new("key-003", 512, 5)
            
            $sorted = @($k1, $k2, $k3) | Sort-Object
            
            $sorted[0].KeyId | Should -Be "key-003"
            $sorted[1].KeyId | Should -Be "key-001"
            $sorted[2].KeyId | Should -Be "key-002"
        }

        It "Should return 1 when comparing to null" {
            $k1 = [CryptoKeyPair]::new("key-001", 256, 30)
            
            $k1.CompareTo($null) | Should -Be 1
        }

        It "Should compare expiry dates correctly" {
            $k1 = [CryptoKeyPair]::new("key-001", 256, 10)
            $k2 = [CryptoKeyPair]::new("key-002", 128, 20)
            
            $k1.CompareTo($k2) | Should -BeLessThan 0
            $k2.CompareTo($k1) | Should -BeGreaterThan 0
        }
    }

    Context "GetHashCode for Hashtable Keying" {
        It "Should deduplicate identical KeyIds in hashtable" {
            $k1 = [CryptoKeyPair]::new("key-001", 256, 30)
            $k2 = [CryptoKeyPair]::new("key-001", 128, 15)
            $k3 = [CryptoKeyPair]::new("key-002", 512, 20)
            
            $hash = @{}
            $hash[$k1] = "first"
            $hash[$k2] = "second"
            $hash[$k3] = "third"
            
            $hash.Count | Should -Be 2
            $hash[$k1] | Should -Be "second"
        }

        It "Should generate consistent hash codes for same KeyId" {
            $k1 = [CryptoKeyPair]::new("key-001", 256, 30)
            $k2 = [CryptoKeyPair]::new("key-001", 128, 15)
            
            $k1.GetHashCode() | Should -Be $k2.GetHashCode()
        }

        It "Should allow different KeyIds as separate hashtable keys" {
            $k1 = [CryptoKeyPair]::new("key-001", 256, 30)
            $k2 = [CryptoKeyPair]::new("key-002", 128, 15)
            
            $hash = @{}
            $hash[$k1] = "value1"
            $hash[$k2] = "value2"
            
            $hash.Count | Should -Be 2
            $hash[$k1] | Should -Be "value1"
            $hash[$k2] | Should -Be "value2"
        }
    }

    Context "Static Helper Methods" {
        It "IsStrongerThan should compare strength correctly" {
            $k1 = [CryptoKeyPair]::new("key-001", 256, 30)
            $k2 = [CryptoKeyPair]::new("key-002", 128, 30)
            
            [CryptoKeyPair]::IsStrongerThan($k1, $k2) | Should -Be $true
            [CryptoKeyPair]::IsStrongerThan($k2, $k1) | Should -Be $false
        }

        It "SelectStronger should return stronger key" {
            $k1 = [CryptoKeyPair]::new("key-001", 256, 30)
            $k2 = [CryptoKeyPair]::new("key-002", 128, 30)
            
            $result = [CryptoKeyPair]::SelectStronger($k1, $k2)
            $result.KeyId | Should -Be "key-001"
            $result.Strength | Should -Be 256
        }

        It "SelectStronger should return first when strengths are equal" {
            $k1 = [CryptoKeyPair]::new("key-001", 256, 30)
            $k2 = [CryptoKeyPair]::new("key-002", 256, 30)
            
            $result = [CryptoKeyPair]::SelectStronger($k1, $k2)
            $result.KeyId | Should -Be "key-001"
        }
    }

    Context "IsExpired Method" {
        It "Should return false for non-expired key" {
            $k = [CryptoKeyPair]::new("key-001", 256, 30)
            
            $k.IsExpired() | Should -Be $false
        }

        It "Should return true for expired key" {
            $k = [CryptoKeyPair]::new("key-001", 256, -1)
            
            $k.IsExpired() | Should -Be $true
        }
    }

    Context "Static Merge Method" {
        It "Should return strongest non-expired key" {
            $k1 = [CryptoKeyPair]::new("key-001", 128, 30)
            $k2 = [CryptoKeyPair]::new("key-002", 256, 30)
            $k3 = [CryptoKeyPair]::new("key-003", 512, 30)
            
            $result = [CryptoKeyPair]::Merge(@($k1, $k2, $k3))
            
            $result.KeyId | Should -Be "key-003"
            $result.Strength | Should -Be 512
        }

        It "Should exclude expired keys" {
            $k1 = [CryptoKeyPair]::new("key-001", 128, 30)
            $k2 = [CryptoKeyPair]::new("key-002", 512, -1)  # expired
            $k3 = [CryptoKeyPair]::new("key-003", 256, 30)
            
            $result = [CryptoKeyPair]::Merge(@($k1, $k2, $k3))
            
            $result.KeyId | Should -Be "key-003"
            $result.Strength | Should -Be 256
        }

        It "Should return null when all keys are expired" {
            $k1 = [CryptoKeyPair]::new("key-001", 128, -1)
            $k2 = [CryptoKeyPair]::new("key-002", 256, -1)
            
            $result = [CryptoKeyPair]::Merge(@($k1, $k2))
            
            $result | Should -BeNullOrEmpty
        }

        It "Should return null when array is empty" {
            $result = [CryptoKeyPair]::Merge(@())
            
            $result | Should -BeNullOrEmpty
        }

        It "Should return null when array is null" {
            $result = [CryptoKeyPair]::Merge($null)
            
            $result | Should -BeNullOrEmpty
        }

        It "Should handle single valid key" {
            $k1 = [CryptoKeyPair]::new("key-001", 256, 30)
            
            $result = [CryptoKeyPair]::Merge(@($k1))
            
            $result.KeyId | Should -Be "key-001"
            $result.Strength | Should -Be 256
        }

        It "Should select strongest when multiple keys have same strength" {
            $k1 = [CryptoKeyPair]::new("key-001", 256, 30)
            $k2 = [CryptoKeyPair]::new("key-002", 256, 30)
            $k3 = [CryptoKeyPair]::new("key-003", 128, 30)
            
            $result = [CryptoKeyPair]::Merge(@($k1, $k2, $k3))
            
            $result.Strength | Should -Be 256
            $result.KeyId | Should -BeIn @("key-001", "key-002")
        }
    }
}
