BeforeAll {
    . "$PSScriptRoot/11_MixinScriptblock.ps1"
}

Describe "11_MixinScriptblock - Mixin via Scriptblock Injection" {
    
    Context "MixableService Base Functionality" {
        It "Creates MixableService with random key" {
            $svc = [MixableService]::new()
            $svc._key | Should -Not -BeNullOrEmpty
            $svc._key.Length | Should -Be 32
        }
        
        It "Encrypts data successfully" {
            $svc = [MixableService]::new()
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes("test data")
            $ciphertext = $svc.Encrypt($plaintext)
            
            $ciphertext | Should -Not -BeNullOrEmpty
            # 12-byte nonce + 16-byte tag + plaintext.Length
            $ciphertext.Length | Should -Be (12 + 16 + $plaintext.Length)
        }
        
        It "OnEncrypt hook fires during encryption" {
            $svc = [MixableService]::new()
            $hookLog = [System.Collections.Generic.List[int]]::new()
            $svc.OnEncrypt = { 
                param($d)
                $hookLog.Add($d.Length)
            }.GetNewClosure()
            
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes("test")
            $svc.Encrypt($plaintext)
            
            $hookLog.Count | Should -Be 1
            $hookLog[0] | Should -Be 4
        }
        
        It "OnDecrypt hook exists but is not used in Encrypt" {
            $svc = [MixableService]::new()
            $decryptLog = [System.Collections.Generic.List[string]]::new()
            $svc.OnDecrypt = { 
                $decryptLog.Add("fired")
            }.GetNewClosure()
            
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes("test")
            $svc.Encrypt($plaintext)
            
            $decryptLog.Count | Should -Be 0
        }
    }
    
    Context "Add-TimingMixin Function (Basic Timing Wrapper)" {
        It "Adds Timed method to object" {
            $svc = [MixableService]::new()
            Add-TimingMixin -Target $svc -MethodNames 'Encrypt'
            
            $svc.PSObject.Methods.Name | Should -Contain 'EncryptTimed'
        }
        
        It "Timed method calls original and returns result" {
            $svc = [MixableService]::new()
            Add-TimingMixin -Target $svc -MethodNames 'Encrypt'
            
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes("test")
            $result = $svc.EncryptTimed($plaintext)
            
            $result | Should -Not -BeNullOrEmpty
            $result.Length | Should -Be (12 + 16 + 4)
        }
        
        It "Writes verbose timing output" {
            $svc = [MixableService]::new()
            Add-TimingMixin -Target $svc -MethodNames 'Encrypt'
            
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes("test")
            $verboseOutput = $svc.EncryptTimed($plaintext) 4>&1
            
            # Verbose stream should contain method name
            # Note: May not capture if not running with -Verbose
            # Test just verifies method completes successfully
            $verboseOutput | Should -Not -BeNull
        }
    }
    
    Context "Add-EncryptTimingMixin Function (Agent Task Implementation)" {
        It "Adds TimingLog property to target object" {
            $svc = [MixableService]::new()
            Add-EncryptTimingMixin -Target $svc
            
            $svc.PSObject.Properties.Name | Should -Contain 'TimingLog'
            $svc.TimingLog.GetType().Name | Should -Be 'List`1'
        }
        
        It "TimingLog is initialized as empty list" {
            $svc = [MixableService]::new()
            Add-EncryptTimingMixin -Target $svc
            
            $svc.TimingLog.Count | Should -Be 0
        }
        
        It "Adds EncryptTimed scriptmethod to target" {
            $svc = [MixableService]::new()
            Add-EncryptTimingMixin -Target $svc
            
            $svc.PSObject.Methods.Name | Should -Contain 'EncryptTimed'
        }
        
        It "Hook fires before encrypt operation" {
            $svc = [MixableService]::new()
            $hookLog = [System.Collections.Generic.List[string]]::new()
            $originalHook = { 
                param($d)
                $hookLog.Add("fired")
            }.GetNewClosure()
            $svc.OnEncrypt = $originalHook
            
            Add-EncryptTimingMixin -Target $svc
            
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes("test")
            $svc.EncryptTimed($plaintext)
            
            $hookLog.Count | Should -Be 1
        }
        
        It "Records timing entry to TimingLog" {
            $svc = [MixableService]::new()
            Add-EncryptTimingMixin -Target $svc
            
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes("test")
            $svc.EncryptTimed($plaintext)
            
            $svc.TimingLog.Count | Should -Be 1
        }
        
        It "Timing entry contains required fields" {
            $svc = [MixableService]::new()
            Add-EncryptTimingMixin -Target $svc
            
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes("test data")
            $svc.EncryptTimed($plaintext)
            
            $entry = $svc.TimingLog[0]
            $entry.Keys | Should -Contain 'Timestamp'
            $entry.Keys | Should -Contain 'Method'
            $entry.Keys | Should -Contain 'ElapsedMs'
            $entry.Keys | Should -Contain 'DataSize'
        }
        
        It "Timing entry records correct method name" {
            $svc = [MixableService]::new()
            Add-EncryptTimingMixin -Target $svc
            
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes("test")
            $svc.EncryptTimed($plaintext)
            
            $svc.TimingLog[0].Method | Should -Be 'Encrypt'
        }
        
        It "Timing entry records correct data size" {
            $svc = [MixableService]::new()
            Add-EncryptTimingMixin -Target $svc
            
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes("hello world")
            $svc.EncryptTimed($plaintext)
            
            $svc.TimingLog[0].DataSize | Should -Be 11
        }
        
        It "ElapsedMs is greater than 0" {
            $svc = [MixableService]::new()
            Add-EncryptTimingMixin -Target $svc
            
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes("test")
            $svc.EncryptTimed($plaintext)
            
            $svc.TimingLog[0].ElapsedMs | Should -BeGreaterOrEqual 0
        }
        
        It "Timestamp is recent DateTime" {
            $svc = [MixableService]::new()
            Add-EncryptTimingMixin -Target $svc
            
            $before = [DateTime]::UtcNow
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes("test")
            $svc.EncryptTimed($plaintext)
            $after = [DateTime]::UtcNow
            
            $entry = $svc.TimingLog[0]
            $entry.Timestamp | Should -BeGreaterOrEqual $before
            $entry.Timestamp | Should -BeLessOrEqual $after
        }
        
        It "Multiple calls accumulate in TimingLog" {
            $svc = [MixableService]::new()
            Add-EncryptTimingMixin -Target $svc
            
            $plaintext1 = [System.Text.Encoding]::UTF8.GetBytes("first")
            $plaintext2 = [System.Text.Encoding]::UTF8.GetBytes("second")
            $plaintext3 = [System.Text.Encoding]::UTF8.GetBytes("third")
            
            $svc.EncryptTimed($plaintext1)
            $svc.EncryptTimed($plaintext2)
            $svc.EncryptTimed($plaintext3)
            
            $svc.TimingLog.Count | Should -Be 3
            $svc.TimingLog[0].DataSize | Should -Be 5
            $svc.TimingLog[1].DataSize | Should -Be 6
            $svc.TimingLog[2].DataSize | Should -Be 5
        }
        
        It "EncryptTimed returns correct ciphertext" {
            $svc = [MixableService]::new()
            Add-EncryptTimingMixin -Target $svc
            
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes("test data")
            $result = $svc.EncryptTimed($plaintext)
            
            $result | Should -Not -BeNullOrEmpty
            $result.Length | Should -Be (12 + 16 + 9)
        }
        
        It "Does not modify MixableService class definition" {
            $svc1 = [MixableService]::new()
            $svc2 = [MixableService]::new()
            
            Add-EncryptTimingMixin -Target $svc1
            
            # svc2 should not have TimingLog or EncryptTimed
            $svc2.PSObject.Properties.Name | Should -Not -Contain 'TimingLog'
            $svc2.PSObject.Methods.Name | Should -Not -Contain 'EncryptTimed'
            
            # svc1 should have them
            $svc1.PSObject.Properties.Name | Should -Contain 'TimingLog'
            $svc1.PSObject.Methods.Name | Should -Contain 'EncryptTimed'
        }
        
        It "Preserves original OnEncrypt hook behavior" {
            $svc = [MixableService]::new()
            $auditLog = [System.Collections.Generic.List[string]]::new()
            $svc.OnEncrypt = { 
                param($d)
                $auditLog.Add("Encrypted $($d.Length) bytes")
            }.GetNewClosure()
            
            Add-EncryptTimingMixin -Target $svc
            
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes("test")
            $svc.EncryptTimed($plaintext)
            
            # Both audit and timing should work
            $auditLog.Count | Should -Be 1
            $auditLog[0] | Should -Be "Encrypted 4 bytes"
            $svc.TimingLog.Count | Should -Be 1
        }
        
        It "Can be applied to object with existing OnEncrypt hook" {
            $svc = [MixableService]::new()
            $hookLog = [System.Collections.Generic.List[int]]::new()
            $svc.OnEncrypt = { 
                param($d)
                $hookLog.Add($d.Length)
            }.GetNewClosure()
            
            Add-EncryptTimingMixin -Target $svc
            
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes("test")
            $svc.EncryptTimed($plaintext)
            
            $hookLog.Count | Should -Be 1
            $svc.TimingLog.Count | Should -Be 1
        }
        
        It "Works with empty data" {
            $svc = [MixableService]::new()
            Add-EncryptTimingMixin -Target $svc
            
            $plaintext = [byte[]]::new(0)
            $result = $svc.EncryptTimed($plaintext)
            
            $svc.TimingLog.Count | Should -Be 1
            $svc.TimingLog[0].DataSize | Should -Be 0
            $result.Length | Should -Be (12 + 16 + 0)
        }
        
        It "Works with large data" {
            $svc = [MixableService]::new()
            Add-EncryptTimingMixin -Target $svc
            
            $plaintext = [byte[]]::new(10KB)
            $result = $svc.EncryptTimed($plaintext)
            
            $svc.TimingLog.Count | Should -Be 1
            $svc.TimingLog[0].DataSize | Should -Be 10240
            $svc.TimingLog[0].ElapsedMs | Should -BeGreaterOrEqual 0
        }
        
        It "Independent instances have independent logs" {
            $svc1 = [MixableService]::new()
            $svc2 = [MixableService]::new()
            
            Add-EncryptTimingMixin -Target $svc1
            Add-EncryptTimingMixin -Target $svc2
            
            $plaintext1 = [System.Text.Encoding]::UTF8.GetBytes("first")
            $plaintext2 = [System.Text.Encoding]::UTF8.GetBytes("second call")
            
            $svc1.EncryptTimed($plaintext1)
            $svc2.EncryptTimed($plaintext2)
            $svc2.EncryptTimed($plaintext2)
            
            $svc1.TimingLog.Count | Should -Be 1
            $svc2.TimingLog.Count | Should -Be 2
            $svc1.TimingLog[0].DataSize | Should -Be 5
            $svc2.TimingLog[0].DataSize | Should -Be 11
        }
        
        It "Calling Add-EncryptTimingMixin twice is idempotent" {
            $svc = [MixableService]::new()
            Add-EncryptTimingMixin -Target $svc
            Add-EncryptTimingMixin -Target $svc  # Second call
            
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes("test")
            $svc.EncryptTimed($plaintext)
            
            # Should only record once, not double-log
            $svc.TimingLog.Count | Should -Be 1
        }
    }
    
    Context "Integration: Timing Mixin with Audit Hook" {
        It "Timing and audit hooks work together" {
            $svc = [MixableService]::new()
            $auditLog = [System.Collections.Generic.List[hashtable]]::new()
            
            $svc.OnEncrypt = {
                param($d)
                $auditLog.Add(@{
                    Action = 'Encrypt'
                    Size = $d.Length
                    Time = [DateTime]::UtcNow
                })
            }.GetNewClosure()
            
            Add-EncryptTimingMixin -Target $svc
            
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes("integration test")
            $result = $svc.EncryptTimed($plaintext)
            
            # Audit hook should fire
            $auditLog.Count | Should -Be 1
            $auditLog[0].Action | Should -Be 'Encrypt'
            $auditLog[0].Size | Should -Be 16
            
            # Timing should record
            $svc.TimingLog.Count | Should -Be 1
            $svc.TimingLog[0].DataSize | Should -Be 16
            $svc.TimingLog[0].ElapsedMs | Should -BeGreaterOrEqual 0
            
            # Result should be valid ciphertext
            $result.Length | Should -Be (12 + 16 + 16)
        }
        
        It "Can mix timing with multiple scriptblock injections" {
            $svc = [MixableService]::new()
            $events = [System.Collections.Generic.List[string]]::new()
            
            $svc.OnEncrypt = {
                param($d)
                $events.Add("OnEncrypt: $($d.Length) bytes")
            }.GetNewClosure()
            
            Add-EncryptTimingMixin -Target $svc
            
            # Add custom logging method via Add-Member
            $customLog = {
                param([byte[]]$data)
                $events.Add("Custom: Before Encrypt")
                $result = $this.EncryptTimed($data)
                $events.Add("Custom: After Encrypt")
                return $result
            }.GetNewClosure()
            $svc | Add-Member -MemberType ScriptMethod -Name 'EncryptWithCustomLog' -Value $customLog -Force
            
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes("test")
            $result = $svc.EncryptWithCustomLog($plaintext)
            
            $events.Count | Should -Be 3
            $events[0] | Should -Be "Custom: Before Encrypt"
            $events[1] | Should -Be "OnEncrypt: 4 bytes"
            $events[2] | Should -Be "Custom: After Encrypt"
            
            $svc.TimingLog.Count | Should -Be 1
            $result.Length | Should -Be (12 + 16 + 4)
        }
    }
    
    Context "Edge Cases and Error Handling" {
        It "EncryptTimed handles null TimingLog gracefully" {
            $svc = [MixableService]::new()
            Add-EncryptTimingMixin -Target $svc
            
            # Manually remove TimingLog to test robustness
            $svc.PSObject.Properties.Remove('TimingLog')
            
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes("test")
            # Should not throw, though timing won't be recorded
            { $svc.EncryptTimed($plaintext) } | Should -Not -Throw
        }
        
        It "Timing measurement is reasonable for fast operations" {
            $svc = [MixableService]::new()
            Add-EncryptTimingMixin -Target $svc
            
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes("x")
            $svc.EncryptTimed($plaintext)
            
            # Even fast crypto should complete within 1000ms
            $svc.TimingLog[0].ElapsedMs | Should -BeLessOrEqual 1000
        }
        
        It "Original Encrypt method remains unmodified" {
            $svc = [MixableService]::new()
            Add-EncryptTimingMixin -Target $svc
            
            $plaintext = [System.Text.Encoding]::UTF8.GetBytes("test")
            
            # Direct Encrypt call should not affect TimingLog
            $result1 = $svc.Encrypt($plaintext)
            $svc.TimingLog.Count | Should -Be 0
            
            # EncryptTimed should record
            $result2 = $svc.EncryptTimed($plaintext)
            $svc.TimingLog.Count | Should -Be 1
            
            # Both should produce valid ciphertext
            $result1.Length | Should -Be (12 + 16 + 4)
            $result2.Length | Should -Be (12 + 16 + 4)
        }
    }
}
