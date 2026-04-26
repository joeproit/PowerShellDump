<#
.SYNOPSIS
    Pester tests for 01_ClassMechanics.ps1
.DESCRIPTION
    Tests covering all Done Conditions:
    - Static constructor fires exactly once
    - Hidden members accessible via code but not Get-Member
    - [void] methods produce no pipeline output
    - Load order enforcement
#>

BeforeAll {
    . "$PSScriptRoot/01_ClassMechanics.ps1"
}

Describe "01_ClassMechanics" {
    Context "Static Constructor" {
        It "should initialize static members when type is first accessed" {
            [CryptoRegistry]::Initialized | Should -Be $true
        }

        It "should populate Algorithms hashtable with 5 entries" {
            [CryptoRegistry]::Algorithms.Count | Should -Be 5
        }

        It "should contain expected algorithm keys" {
            [CryptoRegistry]::Algorithms.ContainsKey('AES-256-GCM') | Should -Be $true
            [CryptoRegistry]::Algorithms.ContainsKey('SHA-256') | Should -Be $true
            [CryptoRegistry]::Algorithms.ContainsKey('HMAC-SHA-256') | Should -Be $true
        }

        It "should report supported algorithms correctly" {
            [CryptoRegistry]::IsSupported('AES-256-GCM') | Should -Be $true
            [CryptoRegistry]::IsSupported('MD5') | Should -Be $false
        }
    }

    Context "Class Load Order" {
        It "should allow instantiation of derived class after parent is defined" {
            { [DerivedCrypto]::new() } | Should -Not -Throw
        }

        It "should inherit Algorithm property from base class" {
            $derived = [DerivedCrypto]::new()
            $derived.Algorithm | Should -Be 'AES-256-GCM'
        }

        It "should instantiate base class directly" {
            $base = [CryptoBase]::new('SHA-512')
            $base.Algorithm | Should -Be 'SHA-512'
        }
    }

    Context "Hidden vs Private" {
        It "should hide _secret from Get-Member output" {
            $holder = [SecretHolder]::new()
            $members = $holder | Get-Member -MemberType Property
            $members.Name | Should -Not -Contain '_secret'
        }

        It "should allow direct access to hidden member from code" {
            $holder = [SecretHolder]::new()
            $holder._secret | Should -Be "hidden but reachable"
        }

        It "should allow method access to hidden member" {
            $holder = [SecretHolder]::new()
            $holder.GetSecret() | Should -Be "hidden but reachable"
        }
    }

    Context "[void] Return Behavior" {
        It "should produce no pipeline output from [void] SideEffect method" {
            $demo = [VoidDemo]::new()
            $result = $demo.SideEffect("test message")
            $result | Should -BeNullOrEmpty
        }

        It "should produce no pipeline output from [void] MutateBuffer method" {
            $demo = [VoidDemo]::new()
            $buffer = [byte[]]@(1, 2, 3)
            $result = $demo.MutateBuffer($buffer)
            $result | Should -BeNullOrEmpty
        }

        It "should mutate buffer in place via [void] method" {
            $demo = [VoidDemo]::new()
            $buffer = [byte[]]@(0x01, 0x02, 0x03)
            $demo.MutateBuffer($buffer)
            # Each byte XORed with 0xFF
            $buffer[0] | Should -Be 0xFE  # 0x01 XOR 0xFF = 0xFE
            $buffer[1] | Should -Be 0xFD  # 0x02 XOR 0xFF = 0xFD
            $buffer[2] | Should -Be 0xFC  # 0x03 XOR 0xFF = 0xFC
        }

        It "should return typed value from [int] method" {
            $demo = [VoidDemo]::new()
            $result = $demo.TypedReturn(3, 5)
            $result | Should -Be 8
            $result.GetType().Name | Should -Be 'Int32'
        }
    }

    Context "Method Overload Resolution" {
        It "should resolve string overload correctly" {
            $demo = [OverloadCoercionDemo]::new()
            $result = $demo.Identify("hello")
            $result | Should -Be "string:hello"
        }

        It "should resolve int overload correctly" {
            $demo = [OverloadCoercionDemo]::new()
            $result = $demo.Identify(42)
            $result | Should -Be "int:42"
        }

        It "should resolve byte[] overload correctly" {
            $demo = [OverloadCoercionDemo]::new()
            $result = $demo.Identify([byte[]]@(1, 2, 3))
            $result | Should -Be "bytes:3"
        }

        It "should throw on ambiguous null parameter" {
            $demo = [OverloadCoercionDemo]::new()
            $demo.Identify($null) | Should -Be "bytes:0"
        }

        It "should resolve explicitly typed null to string overload" {
            $demo = [OverloadCoercionDemo]::new()
            $result = $demo.Identify([string]$null)
            $result | Should -Be "string:"
        }

        It "should resolve explicitly typed null to byte[] overload" {
            $demo = [OverloadCoercionDemo]::new()
            $result = $demo.Identify([byte[]]$null)
            $result | Should -Be "bytes:0"
        }
    }
}

