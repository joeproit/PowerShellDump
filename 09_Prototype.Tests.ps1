BeforeAll {
    . $PSScriptRoot/09_Prototype.ps1
}

Describe "CloneableConfig - Prototype Pattern" {
    Context "Clone() method" {
        It "produces an independent copy" {
            $original = [CloneableConfig]::new("AES", 256)
            $original.Parameters["Mode"] = "CBC"
            $original.Parameters["Padding"] = "PKCS7"
            
            $clone = $original.Clone()
            
            # Verify values are copied
            $clone.Algorithm | Should -Be "AES"
            $clone.KeyBits | Should -Be 256
            $clone.Parameters["Mode"] | Should -Be "CBC"
            $clone.Parameters["Padding"] | Should -Be "PKCS7"
        }

        It "mutating clone does not affect original" {
            $original = [CloneableConfig]::new("AES", 256)
            $original.Parameters["Mode"] = "CBC"
            
            $clone = $original.Clone()
            $clone.Algorithm = "ChaCha20"
            $clone.KeyBits = 512
            $clone.Parameters["Mode"] = "GCM"
            $clone.Parameters["NewParam"] = "Added"
            
            # Original should be unchanged
            $original.Algorithm | Should -Be "AES"
            $original.KeyBits | Should -Be 256
            $original.Parameters["Mode"] | Should -Be "CBC"
            $original.Parameters.ContainsKey("NewParam") | Should -Be $false
        }

        It "deep-copies byte[] KeyMaterial" {
            $original = [CloneableConfig]::new("AES", 256)
            $originalKeySnapshot = [byte[]]::new($original.KeyMaterial.Length)
            [System.Buffer]::BlockCopy($original.KeyMaterial, 0, $originalKeySnapshot, 0, $original.KeyMaterial.Length)
            
            $clone = $original.Clone()
            
            # Keys should be equal initially
            $clone.KeyMaterial | Should -Be $originalKeySnapshot
            
            # Mutate clone's key
            $clone.KeyMaterial[0] = ($clone.KeyMaterial[0] + 1) % 256
            
            # Original should be unchanged
            $original.KeyMaterial | Should -Be $originalKeySnapshot
            $clone.KeyMaterial[0] | Should -Not -Be $original.KeyMaterial[0]
        }

        It "handles empty Parameters hashtable" {
            $original = [CloneableConfig]::new("AES", 128)
            $clone = $original.Clone()
            
            $clone.Parameters.Count | Should -Be 0
            $clone.Parameters | Should -BeOfType [hashtable]
        }

        It "deep-copies Parameters hashtable" {
            $original = [CloneableConfig]::new("AES", 256)
            $original.Parameters["Setting1"] = "Value1"
            $original.Parameters["Setting2"] = 42
            
            $clone = $original.Clone()
            
            # Modify clone's parameters
            $clone.Parameters["Setting1"] = "Modified"
            $clone.Parameters.Remove("Setting2")
            $clone.Parameters["Setting3"] = "New"
            
            # Original should be unchanged
            $original.Parameters["Setting1"] | Should -Be "Value1"
            $original.Parameters["Setting2"] | Should -Be 42
            $original.Parameters.ContainsKey("Setting3") | Should -Be $false
            $original.Parameters.Count | Should -Be 2
        }
    }

    Context "CloneWith() method" {
        It "applies overrides correctly" {
            $original = [CloneableConfig]::new("AES", 256)
            $original.Parameters["Mode"] = "CBC"
            
            $clone = $original.CloneWith(@{
                Algorithm = "ChaCha20"
                KeyBits = 512
            })
            
            $clone.Algorithm | Should -Be "ChaCha20"
            $clone.KeyBits | Should -Be 512
            $clone.Parameters["Mode"] | Should -Be "CBC"
            
            # Original unchanged
            $original.Algorithm | Should -Be "AES"
            $original.KeyBits | Should -Be 256
        }

        It "can override Parameters hashtable" {
            $original = [CloneableConfig]::new("AES", 256)
            $original.Parameters["Mode"] = "CBC"
            
            $newParams = @{ Mode = "GCM"; IV = "random" }
            $clone = $original.CloneWith(@{ Parameters = $newParams })
            
            $clone.Parameters["Mode"] | Should -Be "GCM"
            $clone.Parameters["IV"] | Should -Be "random"
            
            # Original unchanged
            $original.Parameters["Mode"] | Should -Be "CBC"
            $original.Parameters.ContainsKey("IV") | Should -Be $false
        }

        It "can override KeyMaterial" {
            $original = [CloneableConfig]::new("AES", 256)
            $customKey = [byte[]]@(1, 2, 3, 4, 5)
            
            $clone = $original.CloneWith(@{ KeyMaterial = $customKey })
            
            $clone.KeyMaterial.Length | Should -Be 5
            $clone.KeyMaterial[0] | Should -Be 1
            $clone.KeyMaterial[4] | Should -Be 5
        }

        It "handles empty overrides" {
            $original = [CloneableConfig]::new("AES", 256)
            $clone = $original.CloneWith(@{})
            
            $clone.Algorithm | Should -Be $original.Algorithm
            $clone.KeyBits | Should -Be $original.KeyBits
        }
    }

    Context "CloneWithNewKey() method" {
        It "deep-clones config with fresh KeyMaterial" {
            $original = [CloneableConfig]::new("AES", 256)
            $original.Parameters["Mode"] = "CBC"
            $original.Parameters["Padding"] = "PKCS7"
            $originalKeySnapshot = [byte[]]::new($original.KeyMaterial.Length)
            [System.Buffer]::BlockCopy($original.KeyMaterial, 0, $originalKeySnapshot, 0, $original.KeyMaterial.Length)
            
            $clone = $original.CloneWithNewKey()
            
            # Config values should match
            $clone.Algorithm | Should -Be "AES"
            $clone.KeyBits | Should -Be 256
            $clone.Parameters["Mode"] | Should -Be "CBC"
            $clone.Parameters["Padding"] | Should -Be "PKCS7"
            
            # KeyMaterial should be different
            $clone.KeyMaterial.Length | Should -Be $original.KeyMaterial.Length
            $clone.KeyMaterial | Should -Not -Be $originalKeySnapshot
        }

        It "generates cryptographically random KeyMaterial" {
            $original = [CloneableConfig]::new("AES", 256)
            $clone1 = $original.CloneWithNewKey()
            $clone2 = $original.CloneWithNewKey()
            
            # Each clone should have different random keys
            $clone1.KeyMaterial | Should -Not -Be $clone2.KeyMaterial
            $clone1.KeyMaterial | Should -Not -Be $original.KeyMaterial
            $clone2.KeyMaterial | Should -Not -Be $original.KeyMaterial
        }

        It "mutations to clone do not affect original" {
            $original = [CloneableConfig]::new("AES", 256)
            $original.Parameters["Mode"] = "CBC"
            $originalKeySnapshot = [byte[]]::new($original.KeyMaterial.Length)
            [System.Buffer]::BlockCopy($original.KeyMaterial, 0, $originalKeySnapshot, 0, $original.KeyMaterial.Length)
            
            $clone = $original.CloneWithNewKey()
            
            # Mutate clone
            $clone.Algorithm = "ChaCha20"
            $clone.KeyBits = 512
            $clone.Parameters["Mode"] = "GCM"
            $clone.Parameters["NewParam"] = "Test"
            $clone.KeyMaterial[0] = 255
            
            # Original should be unchanged
            $original.Algorithm | Should -Be "AES"
            $original.KeyBits | Should -Be 256
            $original.Parameters["Mode"] | Should -Be "CBC"
            $original.Parameters.ContainsKey("NewParam") | Should -Be $false
            $original.KeyMaterial | Should -Be $originalKeySnapshot
        }

        It "preserves KeyMaterial length from original" {
            $original = [CloneableConfig]::new("AES", 128)
            # Verify original has 32 bytes
            $original.KeyMaterial.Length | Should -Be 32
            
            $clone = $original.CloneWithNewKey()
            
            $clone.KeyMaterial.Length | Should -Be 32
        }
    }

    Context "Constructor behavior" {
        It "initializes with random KeyMaterial" {
            $config1 = [CloneableConfig]::new("AES", 256)
            $config2 = [CloneableConfig]::new("AES", 256)
            
            # Each instance should have different random keys
            $config1.KeyMaterial | Should -Not -Be $config2.KeyMaterial
        }

        It "creates 32-byte KeyMaterial" {
            $config = [CloneableConfig]::new("AES", 256)
            
            $config.KeyMaterial.Length | Should -Be 32
            $config.KeyMaterial.GetType().Name | Should -Be "Byte[]"
        }

        It "initializes empty Parameters hashtable" {
            $config = [CloneableConfig]::new("AES", 256)
            
            $config.Parameters | Should -BeOfType [hashtable]
            $config.Parameters.Count | Should -Be 0
        }
    }
}
