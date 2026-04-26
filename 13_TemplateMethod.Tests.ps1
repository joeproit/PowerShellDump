BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')
}

Describe 'Template Method Pattern - CryptoWorkflow' {
    Context 'Base class CryptoWorkflow' {
        It 'Should enforce step sequence order' {
            # Create a test subclass that tracks order
            $testClass = @'
class TestWorkflow : CryptoWorkflow {
    hidden [byte[]] Encrypt([byte[]]$data) { return $data }
    hidden [byte[]] Sign([byte[]]$data) { return $data }
}
'@
            Invoke-Expression $testClass
            
            $workflow = [TestWorkflow]::new()
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('test data')
            $result = $workflow.Execute($plaintext)
            
            $log = $workflow.GetStepLog()
            $log | Should -HaveCount 6
            $log[0] | Should -Be 'Validate'
            $log[1] | Should -Be 'Compress'
            $log[2] | Should -Be 'Encrypt'
            $log[3] | Should -Be 'Sign'
            $log[4] | Should -Be 'Package'
            $log[5] | Should -Be 'Audit'
        }

        It 'Should reject empty payload in Validate step' {
            $testClass = @'
class TestWorkflow2 : CryptoWorkflow {
    hidden [byte[]] Encrypt([byte[]]$data) { return $data }
    hidden [byte[]] Sign([byte[]]$data) { return $data }
}
'@
            Invoke-Expression $testClass
            
            $workflow = [TestWorkflow2]::new()
            $emptyData = [byte[]]::new(0)
            { $workflow.Execute($emptyData) } | Should -Throw '*Empty payload*'
        }

        It 'Should return hashtable with required keys from Package' {
            $testClass = @'
class TestWorkflow3 : CryptoWorkflow {
    hidden [byte[]] Encrypt([byte[]]$data) { return $data }
    hidden [byte[]] Sign([byte[]]$data) { return $data }
}
'@
            Invoke-Expression $testClass
            
            $workflow = [TestWorkflow3]::new()
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('test')
            $result = $workflow.Execute($plaintext)
            
            $result | Should -BeOfType [hashtable]
            $result.ContainsKey('Payload') | Should -Be $true
            $result.ContainsKey('Timestamp') | Should -Be $true
            $result.ContainsKey('Version') | Should -Be $true
            $result.Version | Should -Be 1
        }

        It 'Should throw NotImplementedException for abstract Encrypt' {
            $testClass = @'
class IncompleteWorkflow : CryptoWorkflow {
    hidden [byte[]] Sign([byte[]]$data) { return $data }
}
'@
            Invoke-Expression $testClass
            
            $workflow = [IncompleteWorkflow]::new()
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('test')
            { $workflow.Execute($plaintext) } | Should -Throw '*Encrypt*'
        }

        It 'Should throw NotImplementedException for abstract Sign' {
            $testClass = @'
class IncompleteWorkflow2 : CryptoWorkflow {
    hidden [byte[]] Encrypt([byte[]]$data) { return $data }
}
'@
            Invoke-Expression $testClass
            
            $workflow = [IncompleteWorkflow2]::new()
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('test')
            { $workflow.Execute($plaintext) } | Should -Throw '*Sign*'
        }
    }

    Context 'GzipAesWorkflow implementation' {
        It 'Should execute complete workflow without errors' {
            $workflow = [GzipAesWorkflow]::new()
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('Hello, Template Method!')
            
            $result = $workflow.Execute($plaintext)
            
            $result | Should -Not -BeNullOrEmpty
            $result.Payload | Should -Not -BeNullOrEmpty
            $result.Payload.Length | Should -BeGreaterThan 0
        }

        It 'Should record all steps in correct order' {
            $workflow = [GzipAesWorkflow]::new()
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('test data')
            
            $null = $workflow.Execute($plaintext)
            $log = $workflow.GetStepLog()
            
            $log | Should -Be @('Validate', 'Compress', 'Encrypt', 'Sign', 'Package', 'Audit')
        }

        It 'Should compress data (Gzip produces different length)' {
            $workflow = [GzipAesWorkflow]::new()
            # Use compressible data
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes(('A' * 1000))
            
            $result = $workflow.Execute($plaintext)
            
            # After compression, encryption, signing, the length should differ
            $result.Payload.Length | Should -Not -Be $plaintext.Length
        }

        It 'Should encrypt with AES-GCM (nonce + tag + ciphertext)' {
            $workflow = [GzipAesWorkflow]::new()
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('test')
            
            $result = $workflow.Execute($plaintext)
            
            # Should have HMAC (32) + nonce (12) + tag (16) + ciphertext
            $result.Payload.Length | Should -BeGreaterThan 60
        }

        It 'Should sign with HMAC (32 bytes prepended)' {
            $workflow = [GzipAesWorkflow]::new()
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('test')
            
            $result = $workflow.Execute($plaintext)
            
            # HMAC adds 32 bytes at the front
            $result.Payload.Length | Should -BeGreaterThan 32
        }

        It 'Should use unique key per instance' {
            $workflow1 = [GzipAesWorkflow]::new()
            $workflow2 = [GzipAesWorkflow]::new()
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('same data')
            
            $result1 = $workflow1.Execute($plaintext)
            $result2 = $workflow2.Execute($plaintext)
            
            # Different keys should produce different outputs
            [System.BitConverter]::ToString($result1.Payload) | Should -Not -Be ([System.BitConverter]::ToString($result2.Payload))
        }
    }

    Context 'ZstdAesWorkflow implementation' {
        It 'Should execute complete workflow without errors' {
            $workflow = [ZstdAesWorkflow]::new()
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('Hello, ZLib compression!')
            
            $result = $workflow.Execute($plaintext)
            
            $result | Should -Not -BeNullOrEmpty
            $result.Payload | Should -Not -BeNullOrEmpty
            $result.Payload.Length | Should -BeGreaterThan 0
        }

        It 'Should record all steps in correct order' {
            $workflow = [ZstdAesWorkflow]::new()
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('test data')
            
            $null = $workflow.Execute($plaintext)
            $log = $workflow.GetStepLog()
            
            $log | Should -Be @('Validate', 'Compress', 'Encrypt', 'Sign', 'Package', 'Audit')
        }

        It 'Should compress data with ZLib' {
            $workflow = [ZstdAesWorkflow]::new()
            # Use compressible data
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes(('B' * 1000))
            
            $result = $workflow.Execute($plaintext)
            
            # After compression, encryption, signing, the length should differ
            $result.Payload.Length | Should -Not -Be $plaintext.Length
        }

        It 'Should encrypt with AES-GCM' {
            $workflow = [ZstdAesWorkflow]::new()
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('zlib test')
            
            $result = $workflow.Execute($plaintext)
            
            # Should have HMAC (32) + nonce (12) + tag (16) + ciphertext
            $result.Payload.Length | Should -BeGreaterThan 60
        }

        It 'Should sign with HMAC' {
            $workflow = [ZstdAesWorkflow]::new()
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('test')
            
            $result = $workflow.Execute($plaintext)
            
            # HMAC adds 32 bytes at the front
            $result.Payload.Length | Should -BeGreaterThan 32
        }

        It 'Should use unique key per instance' {
            $workflow1 = [ZstdAesWorkflow]::new()
            $workflow2 = [ZstdAesWorkflow]::new()
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('same data')
            
            $result1 = $workflow1.Execute($plaintext)
            $result2 = $workflow2.Execute($plaintext)
            
            # Different keys should produce different outputs
            [System.BitConverter]::ToString($result1.Payload) | Should -Not -Be ([System.BitConverter]::ToString($result2.Payload))
        }

        It 'Should produce different output than GzipAesWorkflow for same input' {
            $gzipWorkflow = [GzipAesWorkflow]::new()
            $zlibWorkflow = [ZstdAesWorkflow]::new()
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('compare compression')
            
            $gzipResult = $gzipWorkflow.Execute($plaintext)
            $zlibResult = $zlibWorkflow.Execute($plaintext)
            
            # Different compression algorithms should yield different results
            [System.BitConverter]::ToString($gzipResult.Payload) | Should -Not -Be ([System.BitConverter]::ToString($zlibResult.Payload))
        }
    }

    Context 'Template Method invariance' {
        It 'Should prevent subclass from reordering steps' {
            # The Execute method is sealed by design - subclasses cannot override it
            # They can only override the individual step methods
            $workflow = [GzipAesWorkflow]::new()
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('invariance test')
            
            $result = $workflow.Execute($plaintext)
            $log = $workflow.GetStepLog()
            
            # Verify exact order every time
            $log[0] | Should -Be 'Validate'
            $log[1] | Should -Be 'Compress'
            $log[2] | Should -Be 'Encrypt'
            $log[3] | Should -Be 'Sign'
            $log[4] | Should -Be 'Package'
            $log[5] | Should -Be 'Audit'
        }

        It 'Should execute steps sequentially on multiple calls' {
            $workflow = [ZstdAesWorkflow]::new()
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('first')
            
            $null = $workflow.Execute($plaintext)
            $null = $workflow.Execute($plaintext)
            
            $log = $workflow.GetStepLog()
            
            # Should have two complete sequences
            $log | Should -HaveCount 12
            # First sequence
            $log[0..5] | Should -Be @('Validate', 'Compress', 'Encrypt', 'Sign', 'Package', 'Audit')
            # Second sequence
            $log[6..11] | Should -Be @('Validate', 'Compress', 'Encrypt', 'Sign', 'Package', 'Audit')
        }
    }

    Context 'Step log functionality' {
        It 'Should return empty log before execution' {
            $workflow = [GzipAesWorkflow]::new()
            $log = $workflow.GetStepLog()
            
            $log | Should -HaveCount 0
        }

        It 'Should maintain log across multiple executions' {
            $workflow = [ZstdAesWorkflow]::new()
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('test')
            
            $null = $workflow.Execute($plaintext)
            $null = $workflow.Execute($plaintext)
            $null = $workflow.Execute($plaintext)
            
            $log = $workflow.GetStepLog()
            $log | Should -HaveCount 18  # 6 steps × 3 executions
        }

        It 'Should return array copy, not reference' {
            $workflow = [GzipAesWorkflow]::new()
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes('test')
            
            $null = $workflow.Execute($plaintext)
            $log1 = $workflow.GetStepLog()
            $null = $workflow.Execute($plaintext)
            $log2 = $workflow.GetStepLog()
            
            $log1 | Should -HaveCount 6
            $log2 | Should -HaveCount 12
        }
    }
}
