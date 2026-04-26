BeforeAll {
    . $PSScriptRoot/04_AccessModifiers.ps1
}

Describe "AccessDemo - Public and Hidden Properties" {
    BeforeEach {
        [AccessDemo]::ClearRegistry()
    }
    
    Context "Public property access" {
        It "Should allow direct access to PublicProp" {
            $obj = [AccessDemo]::new()
            $obj.PublicProp | Should -Be "anyone"
            $obj.PublicProp = "modified"
            $obj.PublicProp | Should -Be "modified"
        }
    }
    
    Context "Hidden property behavior" {
        It "Should not expose _hiddenProp in tab completion or Get-Member" {
            $obj = [AccessDemo]::new()
            $members = $obj | Get-Member -MemberType Property
            $hiddenFound = $members | Where-Object { $_.Name -eq '_hiddenProp' }
            $hiddenFound | Should -BeNullOrEmpty
        }
        
        It "Should allow direct access to _hiddenProp within the class" {
            $obj = [AccessDemo]::new()
            # Can still access directly if you know the name
            $obj._hiddenProp | Should -Be "hidden but not private"
        }
        
        It "DEMONSTRATES: Reflection CAN access hidden property (hidden != private)" {
            $obj = [AccessDemo]::new()
            
            # Use reflection to access the hidden property
            # Note: 'hidden' is a PowerShell keyword, but from .NET's perspective
            # it's still a public property - that's the key demonstration!
            $property = [AccessDemo].GetProperty('_hiddenProp')
            
            $property | Should -Not -BeNullOrEmpty
            $property.GetValue($obj) | Should -Be "hidden but not private"
            
            # Modify via reflection
            $property.SetValue($obj, "changed via reflection")
            $property.GetValue($obj) | Should -Be "changed via reflection"
            
            # This proves that 'hidden' only affects PowerShell IntelliSense,
            # not actual .NET accessibility - true privacy requires closures
        }
    }
}

Describe "AccessDemo - Static Members and Registry" {
    BeforeEach {
        [AccessDemo]::ClearRegistry()
        [AccessDemo]::SetMaxRegistrySize(100)
    }
    
    Context "Static instance tracking" {
        It "Should increment InstanceCount on creation" {
            [AccessDemo]::InstanceCount | Should -Be 0
            
            $obj1 = [AccessDemo]::new()
            [AccessDemo]::InstanceCount | Should -Be 1
            
            $obj2 = [AccessDemo]::new()
            [AccessDemo]::InstanceCount | Should -Be 2
        }
        
        It "Should register instances by ReadonlyId" {
            $obj = [AccessDemo]::new()
            $retrieved = [AccessDemo]::GetById($obj.ReadonlyId)
            
            $retrieved | Should -Not -BeNullOrEmpty
            $retrieved.ReadonlyId | Should -Be $obj.ReadonlyId
        }
        
        It "Should track registry size" {
            [AccessDemo]::GetRegistrySize() | Should -Be 0
            
            $obj1 = [AccessDemo]::new()
            [AccessDemo]::GetRegistrySize() | Should -Be 1
            
            $obj2 = [AccessDemo]::new()
            [AccessDemo]::GetRegistrySize() | Should -Be 2
        }
    }
    
    Context "Registry size limit enforcement" {
        It "Should enforce maximum registry size" {
            [AccessDemo]::SetMaxRegistrySize(3)
            
            $obj1 = [AccessDemo]::new()
            $obj2 = [AccessDemo]::new()
            $obj3 = [AccessDemo]::new()
            
            [AccessDemo]::GetRegistrySize() | Should -Be 3
            
            { [AccessDemo]::new() } | Should -Throw "*Registry size limit exceeded*"
        }
        
        It "Should return current max registry size" {
            [AccessDemo]::GetMaxRegistrySize() | Should -Be 100
            
            [AccessDemo]::SetMaxRegistrySize(50)
            [AccessDemo]::GetMaxRegistrySize() | Should -Be 50
        }
        
        It "Should reject invalid max registry size" {
            { [AccessDemo]::SetMaxRegistrySize(0) } | Should -Throw "*must be positive*"
            { [AccessDemo]::SetMaxRegistrySize(-5) } | Should -Throw "*must be positive*"
        }
        
        It "Should clear registry and reset instance count" {
            $obj1 = [AccessDemo]::new()
            $obj2 = [AccessDemo]::new()
            
            [AccessDemo]::GetRegistrySize() | Should -Be 2
            [AccessDemo]::InstanceCount | Should -Be 2
            
            [AccessDemo]::ClearRegistry()
            
            [AccessDemo]::GetRegistrySize() | Should -Be 0
            [AccessDemo]::InstanceCount | Should -Be 0
        }
    }
    
    Context "ReadonlyId simulation" {
        It "Should generate unique ReadonlyId for each instance" {
            $obj1 = [AccessDemo]::new()
            $obj2 = [AccessDemo]::new()
            
            $obj1.ReadonlyId | Should -Not -Be $obj2.ReadonlyId
        }
        
        It "Should have 8-character ReadonlyId" {
            $obj = [AccessDemo]::new()
            $obj.ReadonlyId.Length | Should -Be 8
        }
        
        It "ReadonlyId can be overwritten (simulation only, not true readonly)" {
            $obj = [AccessDemo]::new()
            $originalId = $obj.ReadonlyId
            
            # PowerShell doesn't have true readonly properties, so this succeeds
            $obj.ReadonlyId = "modified"
            $obj.ReadonlyId | Should -Be "modified"
        }
    }
}

Describe "New-SecureVault - Closure-based True Privacy" {
    Context "Independent vault instances" {
        It "Should create independent vaults that do not share state" {
            $vault1 = New-SecureVault -masterPassword "pass1"
            $vault2 = New-SecureVault -masterPassword "pass2"
            
            # Set values in vault1
            & $vault1.Set "secret1" "value1"
            & $vault1.Set "secret2" "value2"
            
            # Set values in vault2
            & $vault2.Set "secret1" "different1"
            & $vault2.Set "secret3" "value3"
            
            # Verify vault1 state
            & $vault1.Get "secret1" | Should -Be "value1"
            & $vault1.Get "secret2" | Should -Be "value2"
            & $vault1.Has "secret3" | Should -Be $false
            
            # Verify vault2 state
            & $vault2.Get "secret1" | Should -Be "different1"
            & $vault2.Has "secret2" | Should -Be $false
            & $vault2.Get "secret3" | Should -Be "value3"
        }
        
        It "Should maintain private state across multiple operations" {
            $vault = New-SecureVault -masterPassword "test"
            
            & $vault.Set "key1" "value1"
            & $vault.Set "key2" "value2"
            & $vault.Set "key3" "value3"
            
            & $vault.Get "key1" | Should -Be "value1"
            & $vault.Get "key2" | Should -Be "value2"
            & $vault.Get "key3" | Should -Be "value3"
            
            & $vault.Has "key1" | Should -Be $true
            & $vault.Has "key4" | Should -Be $false
        }
        
        It "Should update existing keys" {
            $vault = New-SecureVault -masterPassword "test"
            
            & $vault.Set "key" "original"
            & $vault.Get "key" | Should -Be "original"
            
            & $vault.Set "key" "updated"
            & $vault.Get "key" | Should -Be "updated"
        }
        
        It "Private store should not be accessible via reflection or properties" {
            $vault = New-SecureVault -masterPassword "test"
            & $vault.Set "secret" "hidden"
            
            # The vault object should only have the scriptblock properties
            $members = $vault | Get-Member -MemberType NoteProperty
            $storeFound = $members | Where-Object { $_.Name -eq 'store' }
            $storeFound | Should -BeNullOrEmpty
            
            # Should not be able to access $store directly
            $vault.store | Should -BeNullOrEmpty
        }
    }
    
    Context "Basic vault operations" {
        It "Should set and get values" {
            $vault = New-SecureVault -masterPassword "test"
            
            & $vault.Set "mykey" "myvalue"
            & $vault.Get "mykey" | Should -Be "myvalue"
        }
        
        It "Should return null for non-existent keys" {
            $vault = New-SecureVault -masterPassword "test"
            
            & $vault.Get "nonexistent" | Should -BeNullOrEmpty
        }
        
        It "Should correctly report key existence" {
            $vault = New-SecureVault -masterPassword "test"
            
            & $vault.Has "key" | Should -Be $false
            
            & $vault.Set "key" "value"
            & $vault.Has "key" | Should -Be $true
        }
    }
}
