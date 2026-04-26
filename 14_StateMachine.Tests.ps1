BeforeAll {
    . $PSScriptRoot/14_StateMachine.ps1
}

Describe 'CryptoKeyLifecycle State Machine' {
    
    Context 'Initial State' {
        It 'Creates key in Generated state' {
            $key = [CryptoKeyLifecycle]::new('test-key-1')
            $key.State | Should -Be ([KeyState]::Generated)
            $key.KeyId | Should -Be 'test-key-1'
            $key.CreatedAt | Should -Not -BeNullOrEmpty
        }

        It 'Generates 32-byte key material' {
            $key = [CryptoKeyLifecycle]::new('test-key-2')
            $key._material.Length | Should -Be 32
        }

        It 'Initializes history log' {
            $key = [CryptoKeyLifecycle]::new('test-key-3')
            $history = $key.GetHistory()
            $history.Count | Should -BeGreaterThan 0
            $history[0] | Should -Match 'Created in state Generated'
        }
    }

    Context 'Valid Transitions' {
        It 'Transitions from Generated to Active' {
            $key = [CryptoKeyLifecycle]::new('test-key-4')
            $key.Activate()
            $key.State | Should -Be ([KeyState]::Active)
            $key.ActivatedAt | Should -Not -BeNullOrEmpty
        }

        It 'Transitions from Active to Suspended' {
            $key = [CryptoKeyLifecycle]::new('test-key-5')
            $key.Activate()
            $key.Suspend()
            $key.State | Should -Be ([KeyState]::Suspended)
        }

        It 'Transitions from Suspended to Active' {
            $key = [CryptoKeyLifecycle]::new('test-key-6')
            $key.Activate()
            $key.Suspend()
            $key.Resume()
            $key.State | Should -Be ([KeyState]::Active)
        }

        It 'Transitions from Active to Rotated with successor' {
            $key = [CryptoKeyLifecycle]::new('test-key-7')
            $successor = [CryptoKeyLifecycle]::new('test-key-8')
            $key.Activate()
            $key.Rotate($successor)
            $key.State | Should -Be ([KeyState]::Rotated)
            $successor.State | Should -Be ([KeyState]::Active)
            $key.RotatedAt | Should -Not -BeNullOrEmpty
        }

        It 'Transitions from Active to Revoked' {
            $key = [CryptoKeyLifecycle]::new('test-key-9')
            $key.Activate()
            $key.Revoke('Test revocation')
            $key.State | Should -Be ([KeyState]::Revoked)
            $key.RevokedAt | Should -Not -BeNullOrEmpty
        }

        It 'Transitions from Suspended to Revoked' {
            $key = [CryptoKeyLifecycle]::new('test-key-10')
            $key.Activate()
            $key.Suspend()
            $key.Revoke('Revoke while suspended')
            $key.State | Should -Be ([KeyState]::Revoked)
        }

        It 'Transitions from Rotated to Revoked' {
            $key = [CryptoKeyLifecycle]::new('test-key-11')
            $successor = [CryptoKeyLifecycle]::new('test-key-12')
            $key.Activate()
            $key.Rotate($successor)
            $key.Revoke('Revoke after rotation')
            $key.State | Should -Be ([KeyState]::Revoked)
        }

        It 'Transitions from Revoked to Destroyed' {
            $key = [CryptoKeyLifecycle]::new('test-key-13')
            $key.Activate()
            $key.Revoke('Test')
            $key.Destroy()
            $key.State | Should -Be ([KeyState]::Destroyed)
        }
    }

    Context 'Illegal Transitions - Activate()' {
        It 'Throws when Activate() called from Active' {
            $key = [CryptoKeyLifecycle]::new('test-key-14')
            $key.Activate()
            { $key.Activate() } | Should -Throw -ExceptionType ([System.InvalidOperationException])
        }

        It 'Throws when Activate() called from Suspended' {
            $key = [CryptoKeyLifecycle]::new('test-key-15')
            $key.Activate()
            $key.Suspend()
            { $key.Activate() } | Should -Throw -ExceptionType ([System.InvalidOperationException])
        }

        It 'Throws when Activate() called from Rotated' {
            $key = [CryptoKeyLifecycle]::new('test-key-16')
            $successor = [CryptoKeyLifecycle]::new('test-key-17')
            $key.Activate()
            $key.Rotate($successor)
            { $key.Activate() } | Should -Throw -ExceptionType ([System.InvalidOperationException])
        }

        It 'Throws when Activate() called from Revoked' {
            $key = [CryptoKeyLifecycle]::new('test-key-18')
            $key.Activate()
            $key.Revoke('Test')
            { $key.Activate() } | Should -Throw -ExceptionType ([System.InvalidOperationException])
        }

        It 'Throws when Activate() called from Destroyed' {
            $key = [CryptoKeyLifecycle]::new('test-key-19')
            $key.Activate()
            $key.Revoke('Test')
            $key.Destroy()
            { $key.Activate() } | Should -Throw -ExceptionType ([System.InvalidOperationException])
        }
    }

    Context 'Illegal Transitions - Suspend()' {
        It 'Throws when Suspend() called from Generated' {
            $key = [CryptoKeyLifecycle]::new('test-key-20')
            { $key.Suspend() } | Should -Throw -ExceptionType ([System.InvalidOperationException])
        }

        It 'Throws when Suspend() called from Suspended' {
            $key = [CryptoKeyLifecycle]::new('test-key-21')
            $key.Activate()
            $key.Suspend()
            { $key.Suspend() } | Should -Throw -ExceptionType ([System.InvalidOperationException])
        }

        It 'Throws when Suspend() called from Rotated' {
            $key = [CryptoKeyLifecycle]::new('test-key-22')
            $successor = [CryptoKeyLifecycle]::new('test-key-23')
            $key.Activate()
            $key.Rotate($successor)
            { $key.Suspend() } | Should -Throw -ExceptionType ([System.InvalidOperationException])
        }

        It 'Throws when Suspend() called from Revoked' {
            $key = [CryptoKeyLifecycle]::new('test-key-24')
            $key.Activate()
            $key.Revoke('Test')
            { $key.Suspend() } | Should -Throw -ExceptionType ([System.InvalidOperationException])
        }

        It 'Throws when Suspend() called from Destroyed' {
            $key = [CryptoKeyLifecycle]::new('test-key-25')
            $key.Activate()
            $key.Revoke('Test')
            $key.Destroy()
            { $key.Suspend() } | Should -Throw -ExceptionType ([System.InvalidOperationException])
        }
    }

    Context 'Illegal Transitions - Resume()' {
        It 'Throws when Resume() called from Generated' {
            $key = [CryptoKeyLifecycle]::new('test-key-26')
            { $key.Resume() } | Should -Throw -ExceptionType ([System.InvalidOperationException])
        }

        It 'Throws when Resume() called from Active' {
            $key = [CryptoKeyLifecycle]::new('test-key-27')
            $key.Activate()
            { $key.Resume() } | Should -Throw -ExceptionType ([System.InvalidOperationException])
        }

        It 'Throws when Resume() called from Rotated' {
            $key = [CryptoKeyLifecycle]::new('test-key-28')
            $successor = [CryptoKeyLifecycle]::new('test-key-29')
            $key.Activate()
            $key.Rotate($successor)
            { $key.Resume() } | Should -Throw -ExceptionType ([System.InvalidOperationException])
        }

        It 'Throws when Resume() called from Revoked' {
            $key = [CryptoKeyLifecycle]::new('test-key-30')
            $key.Activate()
            $key.Revoke('Test')
            { $key.Resume() } | Should -Throw -ExceptionType ([System.InvalidOperationException])
        }

        It 'Throws when Resume() called from Destroyed' {
            $key = [CryptoKeyLifecycle]::new('test-key-31')
            $key.Activate()
            $key.Revoke('Test')
            $key.Destroy()
            { $key.Resume() } | Should -Throw -ExceptionType ([System.InvalidOperationException])
        }
    }

    Context 'Illegal Transitions - Rotate()' {
        It 'Throws when Rotate() called from Generated' {
            $key = [CryptoKeyLifecycle]::new('test-key-32')
            $successor = [CryptoKeyLifecycle]::new('test-key-33')
            { $key.Rotate($successor) } | Should -Throw -ExceptionType ([System.InvalidOperationException])
        }

        It 'Throws when Rotate() called from Suspended' {
            $key = [CryptoKeyLifecycle]::new('test-key-34')
            $successor = [CryptoKeyLifecycle]::new('test-key-35')
            $key.Activate()
            $key.Suspend()
            { $key.Rotate($successor) } | Should -Throw -ExceptionType ([System.InvalidOperationException])
        }

        It 'Throws when Rotate() called from Rotated' {
            $key = [CryptoKeyLifecycle]::new('test-key-36')
            $successor1 = [CryptoKeyLifecycle]::new('test-key-37')
            $successor2 = [CryptoKeyLifecycle]::new('test-key-38')
            $key.Activate()
            $key.Rotate($successor1)
            { $key.Rotate($successor2) } | Should -Throw -ExceptionType ([System.InvalidOperationException])
        }

        It 'Throws when Rotate() called from Revoked' {
            $key = [CryptoKeyLifecycle]::new('test-key-39')
            $successor = [CryptoKeyLifecycle]::new('test-key-40')
            $key.Activate()
            $key.Revoke('Test')
            { $key.Rotate($successor) } | Should -Throw -ExceptionType ([System.InvalidOperationException])
        }

        It 'Throws when Rotate() called from Destroyed' {
            $key = [CryptoKeyLifecycle]::new('test-key-41')
            $successor = [CryptoKeyLifecycle]::new('test-key-42')
            $key.Activate()
            $key.Revoke('Test')
            $key.Destroy()
            { $key.Rotate($successor) } | Should -Throw -ExceptionType ([System.InvalidOperationException])
        }

        It 'Throws when successor is not in Generated state' {
            $key = [CryptoKeyLifecycle]::new('test-key-43')
            $successor = [CryptoKeyLifecycle]::new('test-key-44')
            $key.Activate()
            $successor.Activate()
            { $key.Rotate($successor) } | Should -Throw -ExceptionType ([System.InvalidOperationException])
        }
    }

    Context 'Illegal Transitions - Revoke()' {
        It 'Throws when Revoke() called from Generated' {
            $key = [CryptoKeyLifecycle]::new('test-key-45')
            { $key.Revoke('Test') } | Should -Throw -ExceptionType ([System.InvalidOperationException])
        }

        It 'Throws when Revoke() called from Revoked' {
            $key = [CryptoKeyLifecycle]::new('test-key-46')
            $key.Activate()
            $key.Revoke('Test')
            { $key.Revoke('Again') } | Should -Throw -ExceptionType ([System.InvalidOperationException])
        }

        It 'Throws when Revoke() called from Destroyed' {
            $key = [CryptoKeyLifecycle]::new('test-key-47')
            $key.Activate()
            $key.Revoke('Test')
            $key.Destroy()
            { $key.Revoke('Again') } | Should -Throw -ExceptionType ([System.InvalidOperationException])
        }
    }

    Context 'Illegal Transitions - Destroy()' {
        It 'Throws when Destroy() called from Generated' {
            $key = [CryptoKeyLifecycle]::new('test-key-48')
            { $key.Destroy() } | Should -Throw -ExceptionType ([System.InvalidOperationException])
        }

        It 'Throws when Destroy() called from Active' {
            $key = [CryptoKeyLifecycle]::new('test-key-49')
            $key.Activate()
            { $key.Destroy() } | Should -Throw -ExceptionType ([System.InvalidOperationException])
        }

        It 'Throws when Destroy() called from Suspended' {
            $key = [CryptoKeyLifecycle]::new('test-key-50')
            $key.Activate()
            $key.Suspend()
            { $key.Destroy() } | Should -Throw -ExceptionType ([System.InvalidOperationException])
        }

        It 'Throws when Destroy() called from Rotated' {
            $key = [CryptoKeyLifecycle]::new('test-key-51')
            $successor = [CryptoKeyLifecycle]::new('test-key-52')
            $key.Activate()
            $key.Rotate($successor)
            { $key.Destroy() } | Should -Throw -ExceptionType ([System.InvalidOperationException])
        }

        It 'Throws when Destroy() called from Destroyed' {
            $key = [CryptoKeyLifecycle]::new('test-key-53')
            $key.Activate()
            $key.Revoke('Test')
            $key.Destroy()
            { $key.Destroy() } | Should -Throw -ExceptionType ([System.InvalidOperationException])
        }
    }

    Context 'Key Material Security' {
        It 'Destroy() zeroes key material' {
            $key = [CryptoKeyLifecycle]::new('test-key-54')
            $key.Activate()
            $key.Revoke('Test')
            $key.Destroy()
            $key._material.Length | Should -Be 0
        }

        It 'GetMaterial() only works in Active state' {
            $key = [CryptoKeyLifecycle]::new('test-key-55')
            $key.Activate()
            $material = $key.GetMaterial()
            $material.Length | Should -Be 32
        }

        It 'GetMaterial() throws in Generated state' {
            $key = [CryptoKeyLifecycle]::new('test-key-56')
            { $key.GetMaterial() } | Should -Throw -ExceptionType ([System.InvalidOperationException])
        }

        It 'GetMaterial() throws in Suspended state' {
            $key = [CryptoKeyLifecycle]::new('test-key-57')
            $key.Activate()
            $key.Suspend()
            { $key.GetMaterial() } | Should -Throw -ExceptionType ([System.InvalidOperationException])
        }

        It 'GetMaterial() throws in Revoked state' {
            $key = [CryptoKeyLifecycle]::new('test-key-58')
            $key.Activate()
            $key.Revoke('Test')
            { $key.GetMaterial() } | Should -Throw -ExceptionType ([System.InvalidOperationException])
        }

        It 'GetMaterial() throws in Destroyed state' {
            $key = [CryptoKeyLifecycle]::new('test-key-59')
            $key.Activate()
            $key.Revoke('Test')
            $key.Destroy()
            { $key.GetMaterial() } | Should -Throw -ExceptionType ([System.InvalidOperationException])
        }
    }

    Context 'History Logging' {
        It 'Records every transition in history' {
            $key = [CryptoKeyLifecycle]::new('test-key-60')
            $key.Activate()
            $key.Suspend()
            $key.Resume()
            $key.Revoke('Test revocation')
            
            $history = $key.GetHistory()
            $history.Count | Should -BeGreaterOrEqual 5
            $history[1] | Should -Match 'Activated'
            $history[2] | Should -Match 'Suspended'
            $history[3] | Should -Match 'Resumed'
            $history[4] | Should -Match 'Revoked'
        }

        It 'Includes state in each history entry' {
            $key = [CryptoKeyLifecycle]::new('test-key-61')
            $key.Activate()
            
            $history = $key.GetHistory()
            $history | ForEach-Object {
                $_ | Should -Match '\|'
            }
        }

        It 'Logs rotation with successor ID' {
            $key = [CryptoKeyLifecycle]::new('test-key-62')
            $successor = [CryptoKeyLifecycle]::new('test-key-63')
            $key.Activate()
            $key.Rotate($successor)
            
            $history = $key.GetHistory()
            $history[-1] | Should -Match 'successor test-key-63'
        }

        It 'Logs destruction message' {
            $key = [CryptoKeyLifecycle]::new('test-key-64')
            $key.Activate()
            $key.Revoke('Test')
            $key.Destroy()
            
            $history = $key.GetHistory()
            $history[-1] | Should -Match 'Destroyed -- key material zeroed'
        }
    }

    Context 'Complex State Flows' {
        It 'Supports multiple suspend/resume cycles' {
            $key = [CryptoKeyLifecycle]::new('test-key-65')
            $key.Activate()
            $key.Suspend()
            $key.Resume()
            $key.Suspend()
            $key.Resume()
            
            $key.State | Should -Be ([KeyState]::Active)
            $history = $key.GetHistory()
            $history.Count | Should -BeGreaterOrEqual 6
        }

        It 'Allows revocation while suspended' {
            $key = [CryptoKeyLifecycle]::new('test-key-66')
            $key.Activate()
            $key.Suspend()
            $key.Revoke('Revoked while suspended')
            
            $key.State | Should -Be ([KeyState]::Revoked)
        }
    }
}
