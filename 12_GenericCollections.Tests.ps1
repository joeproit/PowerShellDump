BeforeAll {
    . $PSScriptRoot/12_GenericCollections.ps1
}

Describe 'TypedKeyStore' {
    
    Context 'Basic Operations' {
        It 'Should store and retrieve byte array keys' {
            $store = [TypedKeyStore]::new()
            $key = [byte[]](1, 2, 3, 4)
            
            $store.Set('testkey', $key)
            $retrieved = $store.Get('testkey')
            
            $retrieved | Should -Not -BeNullOrEmpty
            $retrieved.Length | Should -Be 4
            $retrieved[0] | Should -Be 1
        }
        
        It 'Should throw on Get with missing key' {
            $store = [TypedKeyStore]::new()
            
            { $store.Get('nonexistent') } | Should -Throw -ExpectedMessage "*not found"
        }
        
        It 'Should return key names' {
            $store = [TypedKeyStore]::new()
            $store.Set('key1', [byte[]](1,2))
            $store.Set('key2', [byte[]](3,4))
            
            $names = $store.GetNames()
            $names.Count | Should -Be 2
            $names | Should -Contain 'key1'
            $names | Should -Contain 'key2'
        }
    }
    
    Context 'TryGet Method' {
        It 'Should return false on missing key' {
            $store = [TypedKeyStore]::new()
            $outKey = $null
            
            $result = $store.TryGet('nonexistent', [ref]$outKey)
            
            $result | Should -Be $false
            # Note: PS 7.4.6 arm64 resolves null to byte[], so checking value assertion
            if ($null -ne $outKey -and $outKey -is [byte[]]) {
                $outKey.Length | Should -Be 0
            }
        }
        
        It 'Should return true and populate output on existing key' {
            $store = [TypedKeyStore]::new()
            $key = [byte[]](10, 20, 30)
            $store.Set('exists', $key)
            
            $outKey = $null
            $result = $store.TryGet('exists', [ref]$outKey)
            
            $result | Should -Be $true
            $outKey | Should -Not -BeNullOrEmpty
            $outKey.Length | Should -Be 3
            $outKey[0] | Should -Be 10
        }
        
        It 'Should not throw on missing key' {
            $store = [TypedKeyStore]::new()
            $outKey = $null
            
            { $store.TryGet('nonexistent', [ref]$outKey) } | Should -Not -Throw
        }
    }
    
    Context 'GetExpiredKeys Method' {
        It 'Should return empty array when no keys exist' {
            $store = [TypedKeyStore]::new()
            
            $expired = @($store.GetExpiredKeys(30))
            
            $expired.Count | Should -Be 0
        }
        
        It 'Should return empty array when all keys are recent' {
            $store = [TypedKeyStore]::new()
            $store.Set('recent1', [byte[]](1,2))
            $store.Set('recent2', [byte[]](3,4))
            
            $expired = $store.GetExpiredKeys(1)
            
            $expired.Count | Should -Be 0
        }
        
        It 'Should return keys not accessed within specified days' {
            $store = [TypedKeyStore]::new()
            
            # Set keys
            $store.Set('key1', [byte[]](1,2))
            $store.Set('key2', [byte[]](3,4))
            $store.Set('key3', [byte[]](5,6))
            
            # Manually update last-accessed to simulate old keys
            $store._lastAccessed['key1'] = [datetime]::UtcNow.AddDays(-40)
            $store._lastAccessed['key2'] = [datetime]::UtcNow.AddDays(-20)
            # key3 stays recent
            
            $expired = $store.GetExpiredKeys(30)
            
            $expired.Count | Should -Be 1
            $expired | Should -Contain 'key1'
            $expired | Should -Not -Contain 'key2'
            $expired | Should -Not -Contain 'key3'
        }
        
        It 'Should return correct keys with different thresholds' {
            $store = [TypedKeyStore]::new()
            
            $store.Set('key1', [byte[]](1,2))
            $store.Set('key2', [byte[]](3,4))
            $store.Set('key3', [byte[]](5,6))
            
            $store._lastAccessed['key1'] = [datetime]::UtcNow.AddDays(-100)
            $store._lastAccessed['key2'] = [datetime]::UtcNow.AddDays(-50)
            $store._lastAccessed['key3'] = [datetime]::UtcNow.AddDays(-25)
            
            # 30 days threshold
            $expired30 = $store.GetExpiredKeys(30)
            $expired30.Count | Should -Be 2
            $expired30 | Should -Contain 'key1'
            $expired30 | Should -Contain 'key2'
            
            # 60 days threshold
            $expired60 = $store.GetExpiredKeys(60)
            $expired60.Count | Should -Be 1
            $expired60 | Should -Contain 'key1'
        }
    }
    
    Context 'Last Accessed Timestamp Tracking' {
        It 'Should update last accessed on Get' {
            $store = [TypedKeyStore]::new()
            $store.Set('key1', [byte[]](1,2))
            
            # Set old timestamp
            $store._lastAccessed['key1'] = [datetime]::UtcNow.AddDays(-50)
            
            # Get should update timestamp
            $null = $store.Get('key1')
            
            $expired = $store.GetExpiredKeys(30)
            $expired | Should -Not -Contain 'key1'
        }
        
        It 'Should update last accessed on successful TryGet' {
            $store = [TypedKeyStore]::new()
            $store.Set('key1', [byte[]](1,2))
            
            # Set old timestamp
            $store._lastAccessed['key1'] = [datetime]::UtcNow.AddDays(-50)
            
            # TryGet should update timestamp
            $outKey = $null
            $null = $store.TryGet('key1', [ref]$outKey)
            
            $expired = $store.GetExpiredKeys(30)
            $expired | Should -Not -Contain 'key1'
        }
        
        It 'Should not update last accessed on failed TryGet' {
            $store = [TypedKeyStore]::new()
            $store.Set('key1', [byte[]](1,2))
            
            # Set old timestamp for existing key
            $store._lastAccessed['key1'] = [datetime]::UtcNow.AddDays(-50)
            
            # TryGet on different key should not affect key1
            $outKey = $null
            $null = $store.TryGet('nonexistent', [ref]$outKey)
            
            $expired = $store.GetExpiredKeys(30)
            $expired | Should -Contain 'key1'
        }
    }
    
    Context 'Audit Log' {
        It 'Should log Set operations' {
            $store = [TypedKeyStore]::new()
            $store.Set('key1', [byte[]](1,2))
            $store.Set('key2', [byte[]](3,4))
            
            $log = $store.GetAuditLog()
            
            $log.Count | Should -BeGreaterOrEqual 2
            $log[0] | Should -Match 'SET key1'
            $log[1] | Should -Match 'SET key2'
        }
    }
}
