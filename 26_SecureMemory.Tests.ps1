BeforeAll {
    . $PSScriptRoot/26_SecureMemory.ps1
}

Describe 'PinnedKeyBuffer' {
    It 'derives a pinned 32-byte key from a password and salt' {
        $salt = [byte[]](1, 2, 3, 4, 5, 6, 7, 8)

        $buffer = [PinnedKeyBuffer]::FromPassword('correct horse battery staple', $salt)

        $bytes = $buffer.ReadBytes()
        $bytes.Length | Should -Be 32
        $bytes | Should -Be ([System.Security.Cryptography.Rfc2898DeriveBytes]::Pbkdf2(
            'correct horse battery staple',
            $salt,
            100000,
            [System.Security.Cryptography.HashAlgorithmName]::SHA256,
            32))
        $buffer.IsZeroed() | Should -BeFalse

        $buffer.Dispose()

        $buffer.IsZeroed() | Should -BeTrue
        Should -Throw -ActualValue { $buffer.ReadBytes() } -ExceptionType ([System.ObjectDisposedException])
    }

    It 'zeroes generated buffers on dispose' {
        $buffer = [PinnedKeyBuffer]::Generate(16)

        $buffer.IsZeroed() | Should -BeFalse

        $buffer.Dispose()

        $buffer.IsZeroed() | Should -BeTrue
        Should -Throw -ActualValue { $buffer.ReadBytes() } -ExceptionType ([System.ObjectDisposedException])
    }
}

Describe 'DpapiKeyVault' {
    It 'guards Windows-only protect and unprotect operations' {
        if (-not $IsWindows) {
            $vault = [DpapiKeyVault]::new()

            Should -Throw -ActualValue { $vault.Protect([byte[]](1, 2, 3)) } -ExceptionType ([System.PlatformNotSupportedException])
            Should -Throw -ActualValue { $vault.Unprotect([byte[]](1, 2, 3)) } -ExceptionType ([System.PlatformNotSupportedException])
        }
    }
}
