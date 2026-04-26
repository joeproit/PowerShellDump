BeforeAll {
    . $PSScriptRoot/08_ObjectPool.ps1
}

Describe 'RsaPool' {
    Context 'Construction and Warmup' {
        It 'Pre-warms pool with correct number of instances' {
            $pool = [RsaPool]::new(2048, 3)
            
            $stats = $pool.Stats()
            $stats.PoolDepth | Should -Be 3
            $stats.TotalCreated | Should -Be 3
            $stats.TotalRented | Should -Be 0
            $stats.TotalReturned | Should -Be 0
            $stats.MaxSize | Should -Be 3
            
            $pool.Drain()
        }

        It 'Creates RSA instances with correct key size' {
            $pool = [RsaPool]::new(2048, 2)
            
            $rsa = $pool.Rent()
            try {
                $rsa.KeySize | Should -Be 2048
            } finally {
                $pool.Return($rsa)
                $pool.Drain()
            }
        }
    }

    Context 'Rent and Return Cycle' {
        It 'Rents an RSA instance from pool' {
            $pool = [RsaPool]::new(2048, 2)
            
            $rsa = $pool.Rent()
            $rsa | Should -Not -BeNullOrEmpty
            $rsa | Should -BeOfType [System.Security.Cryptography.RSA]
            
            $stats = $pool.Stats()
            $stats.TotalRented | Should -Be 1
            $stats.PoolDepth | Should -Be 1
            
            $pool.Return($rsa)
            $pool.Drain()
        }

        It 'Returns an RSA instance to pool' {
            $pool = [RsaPool]::new(2048, 2)
            
            $rsa = $pool.Rent()
            $pool.Return($rsa)
            
            $stats = $pool.Stats()
            $stats.TotalReturned | Should -Be 1
            $stats.PoolDepth | Should -Be 2
            
            $pool.Drain()
        }

        It 'Reuses returned instances' {
            $pool = [RsaPool]::new(2048, 1)
            
            $rsa1 = $pool.Rent()
            $pool.Return($rsa1)
            
            $rsa2 = $pool.Rent()
            
            # Should have reused the same instance
            $stats = $pool.Stats()
            $stats.TotalCreated | Should -Be 1
            $stats.TotalRented | Should -Be 2
            
            $pool.Return($rsa2)
            $pool.Drain()
        }
    }

    Context 'Pool Exhaustion' {
        It 'Creates on-demand when pool is exhausted' {
            $pool = [RsaPool]::new(2048, 2)
            
            $rsa1 = $pool.Rent()
            $rsa2 = $pool.Rent()
            
            # Pool should be empty now
            $stats = $pool.Stats()
            $stats.PoolDepth | Should -Be 0
            
            # Rent a third - should create on demand (and emit warning)
            $rsa3 = $pool.Rent() 3> $null
            
            $stats = $pool.Stats()
            $stats.TotalCreated | Should -Be 3
            $stats.PoolDepth | Should -Be 0
            
            $pool.Return($rsa1)
            $pool.Return($rsa2)
            $pool.Return($rsa3)
            $pool.Drain()
        }

        It 'Disposes excess instances on return' {
            $pool = [RsaPool]::new(2048, 2)
            
            # Rent all from pool
            $rsa1 = $pool.Rent()
            $rsa2 = $pool.Rent()
            
            # Create on-demand (3rd instance)
            $rsa3 = $pool.Rent()
            
            # Return all three
            $pool.Return($rsa1)
            $pool.Return($rsa2)
            
            # Pool is now full (2 instances)
            $stats = $pool.Stats()
            $stats.PoolDepth | Should -Be 2
            
            # Returning 3rd should dispose it (not add to pool)
            $pool.Return($rsa3)
            
            $stats = $pool.Stats()
            $stats.PoolDepth | Should -Be 2  # Still only 2 in pool
            $stats.TotalReturned | Should -Be 3
            
            $pool.Drain()
        }
    }

    Context 'Rent All and Verify Empty Pool' {
        It 'Drains pool completely when all instances are rented' {
            $pool = [RsaPool]::new(2048, 5)
            
            # Initial state
            $stats = $pool.Stats()
            $stats.PoolDepth | Should -Be 5
            
            # Rent all 5
            $instances = @()
            for ($i = 0; $i -lt 5; $i++) {
                $instances += $pool.Rent()
            }
            
            # Verify pool is empty
            $stats = $pool.Stats()
            $stats.PoolDepth | Should -Be 0
            $stats.TotalRented | Should -Be 5
            $stats.TotalCreated | Should -Be 5
            
            # Return all
            foreach ($rsa in $instances) {
                $pool.Return($rsa)
            }
            
            # Verify pool is refilled
            $stats = $pool.Stats()
            $stats.PoolDepth | Should -Be 5
            $stats.TotalReturned | Should -Be 5
            
            $pool.Drain()
        }
    }

    Context 'Drain' {
        It 'Disposes all pooled instances' {
            $pool = [RsaPool]::new(2048, 3)
            
            $pool.Drain()
            
            $stats = $pool.Stats()
            $stats.PoolDepth | Should -Be 0
            $stats.TotalCreated | Should -Be 3  # Still shows created count
        }

        It 'Works with partially rented pool' {
            $pool = [RsaPool]::new(2048, 3)
            
            # Rent one
            $rsa = $pool.Rent()
            
            # Drain remaining 2
            $pool.Drain()
            
            $stats = $pool.Stats()
            $stats.PoolDepth | Should -Be 0
            
            # Return the one we rented
            $pool.Return($rsa)
            
            $stats = $pool.Stats()
            $stats.PoolDepth | Should -Be 1
            
            $pool.Drain()
        }
    }

    Context 'Stats Method' {
        It 'Returns correct statistics' {
            $pool = [RsaPool]::new(2048, 3)
            
            $stats = $pool.Stats()
            
            $stats | Should -BeOfType [hashtable]
            $stats.Keys | Should -Contain 'PoolDepth'
            $stats.Keys | Should -Contain 'TotalCreated'
            $stats.Keys | Should -Contain 'TotalRented'
            $stats.Keys | Should -Contain 'TotalReturned'
            $stats.Keys | Should -Contain 'MaxSize'
            
            $pool.Drain()
        }

        It 'Tracks rent/return operations accurately' {
            $pool = [RsaPool]::new(2048, 2)
            
            $rsa1 = $pool.Rent()
            $rsa2 = $pool.Rent()
            $rsa3 = $pool.Rent()  # On-demand
            
            $pool.Return($rsa1)
            $pool.Return($rsa2)
            
            $stats = $pool.Stats()
            $stats.TotalCreated | Should -Be 3
            $stats.TotalRented | Should -Be 3
            $stats.TotalReturned | Should -Be 2
            $stats.PoolDepth | Should -Be 2
            
            $pool.Return($rsa3)
            $pool.Drain()
        }
    }

    Context 'Real Crypto Operations' {
        It 'Can sign data with rented RSA instance' {
            $pool = [RsaPool]::new(2048, 1)
            
            $rsa = $pool.Rent()
            try {
                $data = [byte[]]@(1, 2, 3, 4, 5)
                $signature = $rsa.SignData(
                    $data,
                    [System.Security.Cryptography.HashAlgorithmName]::SHA256,
                    [System.Security.Cryptography.RSASignaturePadding]::Pss
                )
                
                $signature | Should -Not -BeNullOrEmpty
                $signature.Length | Should -BeGreaterThan 0
                
                # Verify the signature
                $verified = $rsa.VerifyData(
                    $data,
                    $signature,
                    [System.Security.Cryptography.HashAlgorithmName]::SHA256,
                    [System.Security.Cryptography.RSASignaturePadding]::Pss
                )
                
                $verified | Should -Be $true
            } finally {
                $pool.Return($rsa)
                $pool.Drain()
            }
        }

        It 'Multiple rentals can perform independent operations' {
            $pool = [RsaPool]::new(2048, 2)
            
            $rsa1 = $pool.Rent()
            $rsa2 = $pool.Rent()
            
            try {
                $data1 = [byte[]]@(10, 20, 30)
                $data2 = [byte[]]@(40, 50, 60)
                
                $sig1 = $rsa1.SignData(
                    $data1,
                    [System.Security.Cryptography.HashAlgorithmName]::SHA256,
                    [System.Security.Cryptography.RSASignaturePadding]::Pss
                )
                
                $sig2 = $rsa2.SignData(
                    $data2,
                    [System.Security.Cryptography.HashAlgorithmName]::SHA256,
                    [System.Security.Cryptography.RSASignaturePadding]::Pss
                )
                
                # Signatures should be different
                $sig1 | Should -Not -Be $sig2
                
                # Each can verify its own data
                $rsa1.VerifyData($data1, $sig1, 
                    [System.Security.Cryptography.HashAlgorithmName]::SHA256,
                    [System.Security.Cryptography.RSASignaturePadding]::Pss) | Should -Be $true
                    
                $rsa2.VerifyData($data2, $sig2,
                    [System.Security.Cryptography.HashAlgorithmName]::SHA256,
                    [System.Security.Cryptography.RSASignaturePadding]::Pss) | Should -Be $true
            } finally {
                $pool.Return($rsa1)
                $pool.Return($rsa2)
                $pool.Drain()
            }
        }
    }

    Context 'Edge Cases' {
        It 'Handles single-instance pool correctly' {
            $pool = [RsaPool]::new(2048, 1)
            
            $rsa = $pool.Rent()
            $stats = $pool.Stats()
            $stats.PoolDepth | Should -Be 0
            
            $pool.Return($rsa)
            $stats = $pool.Stats()
            $stats.PoolDepth | Should -Be 1
            
            $pool.Drain()
        }

        It 'Handles large pool size' {
            $pool = [RsaPool]::new(2048, 10)
            
            $stats = $pool.Stats()
            $stats.PoolDepth | Should -Be 10
            $stats.TotalCreated | Should -Be 10
            
            $pool.Drain()
        }
    }
}
