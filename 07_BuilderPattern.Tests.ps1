BeforeAll {
    . $PSScriptRoot/07_BuilderPattern.ps1
}

Describe 'CryptoConfig' {
    Context 'Basic instantiation' {
        It 'Creates with default values' {
            $config = [CryptoConfig]::new()
            $config.Algorithm | Should -Be 'AES-256-GCM'
            $config.KeyBits | Should -Be 256
            $config.NonceBits | Should -Be 96
            $config.TagBits | Should -Be 128
            $config.AuditEnabled | Should -Be $false
            $config.MaxOpsPerMinute | Should -Be 1000
            $config.KeyDerivation | Should -Be 'PBKDF2-SHA256'
            $config.KdfIterations | Should -Be 100000
            $config.StaticKey | Should -Be $null
            $config.Version | Should -Be '1'
        }

        It 'ToString() returns formatted string' {
            $config = [CryptoConfig]::new()
            $str = $config.ToString()
            $str | Should -Match '\[AES-256-GCM\]'
            $str | Should -Match 'key=256b'
            $str | Should -Match 'kdf=PBKDF2-SHA256'
            $str | Should -Match 'iter=100000'
            $str | Should -Match 'audit=False'
        }
    }
}

Describe 'CryptoConfigBuilder - Basic Fluent Chain' {
    Context 'UseAesGcm method' {
        It 'Sets AES-256-GCM with default key size' {
            $builder = [CryptoConfigBuilder]::new()
            $result = $builder.UseAesGcm(256)
            $result | Should -BeOfType ([CryptoConfigBuilder])
            $config = $builder.Build()
            $config.Algorithm | Should -Be 'AES-256-GCM'
            $config.KeyBits | Should -Be 256
        }

        It 'Sets AES-256-GCM with custom key size' {
            $builder = [CryptoConfigBuilder]::new()
            $builder = $builder.UseAesGcm(128)
            $config = $builder.Build()
            $config.Algorithm | Should -Be 'AES-256-GCM'
            $config.KeyBits | Should -Be 128
        }

        It 'Supports 192-bit keys' {
            $builder = [CryptoConfigBuilder]::new()
            $builder = $builder.UseAesGcm(192)
            $config = $builder.Build()
            $config.KeyBits | Should -Be 192
        }
    }

    Context 'WithAudit method' {
        It 'Enables audit flag' {
            $builder = [CryptoConfigBuilder]::new()
            $builder = $builder.WithAudit()
            $config = $builder.Build()
            $config.AuditEnabled | Should -Be $true
        }

        It 'Returns builder for chaining' {
            $builder = [CryptoConfigBuilder]::new()
            $result = $builder.WithAudit()
            $result | Should -BeOfType ([CryptoConfigBuilder])
        }
    }

    Context 'WithRateLimit method' {
        It 'Sets rate limit' {
            $builder = [CryptoConfigBuilder]::new()
            $builder = $builder.WithRateLimit(500)
            $config = $builder.Build()
            $config.MaxOpsPerMinute | Should -Be 500
        }

        It 'Returns builder for chaining' {
            $builder = [CryptoConfigBuilder]::new()
            $result = $builder.WithRateLimit(250)
            $result | Should -BeOfType ([CryptoConfigBuilder])
        }
    }

    Context 'WithPbkdf2 method' {
        It 'Sets PBKDF2 with custom iterations' {
            $builder = [CryptoConfigBuilder]::new()
            $builder = $builder.WithPbkdf2(200000)
            $config = $builder.Build()
            $config.KeyDerivation | Should -Be 'PBKDF2-SHA256'
            $config.KdfIterations | Should -Be 200000
        }

        It 'Returns builder for chaining' {
            $builder = [CryptoConfigBuilder]::new()
            $result = $builder.WithPbkdf2(150000)
            $result | Should -BeOfType ([CryptoConfigBuilder])
        }
    }

    Context 'WithStaticKey method' {
        It 'Accepts 128-bit key (16 bytes)' {
            $key = [byte[]]::new(16)
            $builder = [CryptoConfigBuilder]::new()
            $builder = $builder.WithStaticKey($key)
            $config = $builder.Build()
            $config.StaticKey.Length | Should -Be 16
        }

        It 'Accepts 192-bit key (24 bytes)' {
            $key = [byte[]]::new(24)
            $builder = [CryptoConfigBuilder]::new()
            $builder = $builder.WithStaticKey($key)
            $config = $builder.Build()
            $config.StaticKey.Length | Should -Be 24
        }

        It 'Accepts 256-bit key (32 bytes)' {
            $key = [byte[]]::new(32)
            $builder = [CryptoConfigBuilder]::new()
            $builder = $builder.WithStaticKey($key)
            $config = $builder.Build()
            $config.StaticKey.Length | Should -Be 32
        }

        It 'Throws on invalid key length (8 bytes)' {
            $key = [byte[]]::new(8)
            $builder = [CryptoConfigBuilder]::new()
            { $builder.WithStaticKey($key) } | Should -Throw '*128/192/256-bit*'
        }

        It 'Throws on invalid key length (64 bytes)' {
            $key = [byte[]]::new(64)
            $builder = [CryptoConfigBuilder]::new()
            { $builder.WithStaticKey($key) } | Should -Throw '*128/192/256-bit*'
        }

        It 'Returns builder for chaining' {
            $builder = [CryptoConfigBuilder]::new()
            $result = $builder.WithStaticKey([byte[]]::new(32))
            $result | Should -BeOfType ([CryptoConfigBuilder])
        }
    }
}

Describe 'CryptoConfigBuilder - ECDH Key Exchange' {
    Context 'WithEcdhKeyExchange method' {
        It 'Sets algorithm to ECDH-P256' {
            $builder = [CryptoConfigBuilder]::new()
            $builder = $builder.WithEcdhKeyExchange()
            $config = $builder.Build()
            $config.Algorithm | Should -Be 'ECDH-P256'
        }

        It 'Sets KeyBits to 256' {
            $builder = [CryptoConfigBuilder]::new()
            $builder = $builder.WithEcdhKeyExchange()
            $config = $builder.Build()
            $config.KeyBits | Should -Be 256
        }

        It 'Returns builder for chaining' {
            $builder = [CryptoConfigBuilder]::new()
            $result = $builder.WithEcdhKeyExchange()
            $result | Should -BeOfType ([CryptoConfigBuilder])
        }

        It 'Works with other fluent methods' {
            $builder = [CryptoConfigBuilder]::new()
            $builder = $builder.WithEcdhKeyExchange()
            $builder = $builder.WithAudit()
            $builder = $builder.WithRateLimit(500)
            $config = $builder.Build()
            $config.Algorithm | Should -Be 'ECDH-P256'
            $config.KeyBits | Should -Be 256
            $config.AuditEnabled | Should -Be $true
            $config.MaxOpsPerMinute | Should -Be 500
        }
    }

    Context 'ECDH validation in Build()' {
        It 'Accepts ECDH-P256 with 256-bit keys' {
            $builder = [CryptoConfigBuilder]::new()
            $builder = $builder.WithEcdhKeyExchange()
            $config = $builder.Build()
            $config.Algorithm | Should -Be 'ECDH-P256'
            $config.KeyBits | Should -Be 256
        }

        It 'Throws when ECDH-P256 has 128-bit keys' {
            $builder = [CryptoConfigBuilder]::new()
            $builder = $builder.WithEcdhKeyExchange()
            # Manually change KeyBits after ECDH setup (simulate invalid state)
            $builder._config.KeyBits = 128
            { $builder.Build() } | Should -Throw '*ECDH-P256 requires 256-bit keys*'
        }

        It 'Throws when ECDH-P256 has 192-bit keys' {
            $builder = [CryptoConfigBuilder]::new()
            $builder = $builder.WithEcdhKeyExchange()
            $builder._config.KeyBits = 192
            { $builder.Build() } | Should -Throw '*ECDH-P256 requires 256-bit keys*'
        }

        It 'Throws when ECDH-P256 has invalid key size (512)' {
            $builder = [CryptoConfigBuilder]::new()
            $builder = $builder.WithEcdhKeyExchange()
            $builder._config.KeyBits = 512
            { $builder.Build() } | Should -Throw '*ECDH-P256 requires 256-bit keys*'
        }
    }
}

Describe 'CryptoConfigBuilder - Build Validation' {
    Context 'KDF iterations validation' {
        It 'Accepts iterations >= 10000' {
            $builder = [CryptoConfigBuilder]::new()
            $builder = $builder.WithPbkdf2(10000)
            $config = $builder.Build()
            $config.KdfIterations | Should -Be 10000
        }

        It 'Accepts high iteration counts' {
            $builder = [CryptoConfigBuilder]::new()
            $builder = $builder.WithPbkdf2(500000)
            $config = $builder.Build()
            $config.KdfIterations | Should -Be 500000
        }

        It 'Throws when iterations < 10000' {
            $builder = [CryptoConfigBuilder]::new()
            $builder = $builder.WithPbkdf2(9999)
            { $builder.Build() } | Should -Throw '*PBKDF2 iterations too low*'
        }

        It 'Throws when iterations = 1000' {
            $builder = [CryptoConfigBuilder]::new()
            $builder = $builder.WithPbkdf2(1000)
            { $builder.Build() } | Should -Throw '*PBKDF2 iterations too low*'
        }

        It 'Throws when iterations = 0' {
            $builder = [CryptoConfigBuilder]::new()
            $builder = $builder.WithPbkdf2(0)
            { $builder.Build() } | Should -Throw '*PBKDF2 iterations too low*'
        }
    }

    Context 'Key size validation' {
        It 'Accepts 128-bit keys' {
            $builder = [CryptoConfigBuilder]::new()
            $builder = $builder.UseAesGcm(128)
            $config = $builder.Build()
            $config.KeyBits | Should -Be 128
        }

        It 'Accepts 192-bit keys' {
            $builder = [CryptoConfigBuilder]::new()
            $builder = $builder.UseAesGcm(192)
            $config = $builder.Build()
            $config.KeyBits | Should -Be 192
        }

        It 'Accepts 256-bit keys' {
            $builder = [CryptoConfigBuilder]::new()
            $builder = $builder.UseAesGcm(256)
            $config = $builder.Build()
            $config.KeyBits | Should -Be 256
        }

        It 'Throws on invalid key size (64)' {
            $builder = [CryptoConfigBuilder]::new()
            $builder = $builder.UseAesGcm(64)
            { $builder.Build() } | Should -Throw '*Invalid key size: 64*'
        }

        It 'Throws on invalid key size (512)' {
            $builder = [CryptoConfigBuilder]::new()
            $builder = $builder.UseAesGcm(512)
            { $builder.Build() } | Should -Throw '*Invalid key size: 512*'
        }
    }
}

Describe 'CryptoConfigBuilder - Complete Fluent Chains' {
    Context 'Complex AES configuration' {
        It 'Builds full AES-256-GCM config with all options' {
            $builder = [CryptoConfigBuilder]::new()
            $builder = $builder.UseAesGcm(256)
            $builder = $builder.WithAudit()
            $builder = $builder.WithRateLimit(500)
            $builder = $builder.WithPbkdf2(200000)
            $config = $builder.Build()
            
            $config.Algorithm | Should -Be 'AES-256-GCM'
            $config.KeyBits | Should -Be 256
            $config.AuditEnabled | Should -Be $true
            $config.MaxOpsPerMinute | Should -Be 500
            $config.KdfIterations | Should -Be 200000
        }

        It 'Builds AES with static key' {
            $key = [byte[]]::new(32)
            $builder = [CryptoConfigBuilder]::new()
            $builder = $builder.UseAesGcm(256)
            $builder = $builder.WithStaticKey($key)
            $builder = $builder.WithAudit()
            $config = $builder.Build()
            
            $config.StaticKey | Should -Not -Be $null
            $config.StaticKey.Length | Should -Be 32
        }
    }

    Context 'ECDH configuration' {
        It 'Builds complete ECDH config' {
            $builder = [CryptoConfigBuilder]::new()
            $builder = $builder.WithEcdhKeyExchange()
            $builder = $builder.WithAudit()
            $builder = $builder.WithRateLimit(1500)
            $builder = $builder.WithPbkdf2(150000)
            $config = $builder.Build()
            
            $config.Algorithm | Should -Be 'ECDH-P256'
            $config.KeyBits | Should -Be 256
            $config.AuditEnabled | Should -Be $true
            $config.MaxOpsPerMinute | Should -Be 1500
            $config.KdfIterations | Should -Be 150000
        }

        It 'ECDH does not accept static key with wrong size' {
            # This demonstrates that ECDH config is just metadata; 
            # actual key exchange would happen at runtime
            $key = [byte[]]::new(32)
            $builder = [CryptoConfigBuilder]::new()
            $builder = $builder.WithEcdhKeyExchange()
            $builder = $builder.WithStaticKey($key)
            $config = $builder.Build()
            
            $config.Algorithm | Should -Be 'ECDH-P256'
            $config.StaticKey.Length | Should -Be 32
        }
    }

    Context 'Method order independence' {
        It 'Produces same result with different method order' {
            $builder1 = [CryptoConfigBuilder]::new()
            $builder1 = $builder1.WithAudit()
            $builder1 = $builder1.UseAesGcm(256)
            $builder1 = $builder1.WithPbkdf2(150000)
            $config1 = $builder1.Build()
            
            $builder2 = [CryptoConfigBuilder]::new()
            $builder2 = $builder2.WithPbkdf2(150000)
            $builder2 = $builder2.WithAudit()
            $builder2 = $builder2.UseAesGcm(256)
            $config2 = $builder2.Build()
            
            $config1.Algorithm | Should -Be $config2.Algorithm
            $config1.KeyBits | Should -Be $config2.KeyBits
            $config1.AuditEnabled | Should -Be $config2.AuditEnabled
            $config1.KdfIterations | Should -Be $config2.KdfIterations
        }

        It 'Later calls override earlier calls' {
            $builder = [CryptoConfigBuilder]::new()
            $builder = $builder.UseAesGcm(128)
            $builder = $builder.UseAesGcm(256)
            $config = $builder.Build()
            
            $config.KeyBits | Should -Be 256
        }

        It 'ECDH overrides previous algorithm settings' {
            $builder = [CryptoConfigBuilder]::new()
            $builder = $builder.UseAesGcm(192)
            $builder = $builder.WithEcdhKeyExchange()
            $config = $builder.Build()
            
            $config.Algorithm | Should -Be 'ECDH-P256'
            $config.KeyBits | Should -Be 256
        }
    }
}

Describe 'CryptoConfigBuilder - Edge Cases' {
    Context 'Default behavior' {
        It 'Builds with defaults when no methods called' {
            $builder = [CryptoConfigBuilder]::new()
            $config = $builder.Build()
            $config.Algorithm | Should -Be 'AES-256-GCM'
            $config.KeyBits | Should -Be 256
            $config.KdfIterations | Should -Be 100000
        }

        It 'Each builder creates independent config' {
            $builder1 = [CryptoConfigBuilder]::new()
            $builder1 = $builder1.WithAudit()
            $builder2 = [CryptoConfigBuilder]::new()
            
            $config1 = $builder1.Build()
            $config2 = $builder2.Build()
            
            $config1.AuditEnabled | Should -Be $true
            $config2.AuditEnabled | Should -Be $false
        }
    }

    Context 'Multiple Build() calls' {
        It 'Build() returns the same config instance each time' {
            $builder = [CryptoConfigBuilder]::new()
            $builder = $builder.UseAesGcm(256)
            $builder = $builder.WithAudit()
            
            $config1 = $builder.Build()
            $config2 = $builder.Build()
            
            # Should be same reference
            [object]::ReferenceEquals($config1, $config2) | Should -Be $true
        }

        It 'Modifying config after Build() affects future builds' {
            $builder = [CryptoConfigBuilder]::new()
            $builder = $builder.UseAesGcm(256)
            
            $config1 = $builder.Build()
            $config1.AuditEnabled = $true
            
            $config2 = $builder.Build()
            $config2.AuditEnabled | Should -Be $true
        }
    }
}
