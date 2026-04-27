BeforeAll {
    . $PSScriptRoot/25_ReplayPrevention.ps1
}

Describe 'NonceManager' {
    It 'reports nonce count and remaining window seconds' {
        $manager = [NonceManager]::new(2)

        $stats = $manager.GetWindowStats()

        $stats.NonceCount | Should -Be 0
        $stats.WindowRemainingSeconds | Should -Be 0

        $manager.CheckAndRecord('abc') | Should -BeTrue

        $stats = $manager.GetWindowStats()

        $stats.NonceCount | Should -Be 1
        $stats.WindowRemainingSeconds | Should -BeGreaterThan 0
    }
}

Describe 'ReplayResistantCrypto' {
    It 'accepts first use and rejects replay within the window' {
        $crypto = [ReplayResistantCrypto]::new(2)
        $pkg = $crypto.Seal([byte[]](65, 66, 67))

        $opened = $crypto.Open($pkg)
        $opened | Should -Be ([byte[]](65, 66, 67))

        { $crypto.Open($pkg) } | Should -Throw
    }

    It 'accepts the same nonce again after the window expires' {
        $crypto = [ReplayResistantCrypto]::new(1)
        $pkg = $crypto.Seal([byte[]](1, 2, 3, 4))

        $crypto.Open($pkg) | Should -Be ([byte[]](1, 2, 3, 4))

        Start-Sleep -Milliseconds 1200

        $reopened = $crypto.Open($pkg)
        $reopened | Should -Be ([byte[]](1, 2, 3, 4))
    }
}
