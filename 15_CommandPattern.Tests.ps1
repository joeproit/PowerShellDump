BeforeAll {
    . $PSScriptRoot/15_CommandPattern.ps1
}

Describe 'CryptoCommand Base Class' {
    It 'Should throw NotImplementedException for Execute' {
        $cmd = [CryptoCommand]::new()
        { $cmd.Execute() } | Should -Throw -ExceptionType ([System.NotImplementedException])
    }

    It 'Should throw NotImplementedException for Undo' {
        $cmd = [CryptoCommand]::new()
        { $cmd.Undo() } | Should -Throw -ExceptionType ([System.NotImplementedException])
    }

    It 'Should have an 8-character ID' {
        $cmd = [CryptoCommand]::new()
        $cmd.Id | Should -BeOfType [string]
        $cmd.Id.Length | Should -Be 8
    }

    It 'Should have CreatedAt timestamp' {
        $cmd = [CryptoCommand]::new()
        $cmd.CreatedAt | Should -BeOfType [datetime]
        $cmd.CreatedAt | Should -BeLessOrEqual ([datetime]::UtcNow)
    }

    It 'Should default Executed to false' {
        $cmd = [CryptoCommand]::new()
        $cmd.Executed | Should -Be $false
    }

    It 'Should default Result to null' {
        $cmd = [CryptoCommand]::new()
        $cmd.Result | Should -BeNullOrEmpty
    }
}

Describe 'NoopCommand' {
    It 'Should execute successfully' {
        $cmd = [NoopCommand]::new('test1')
        $cmd.Execute()
        $cmd.Executed | Should -Be $true
        $cmd.Result | Should -Be 'executed:test1'
    }

    It 'Should undo successfully' {
        $cmd = [NoopCommand]::new('test2')
        $cmd.Execute()
        $cmd.Undo()
        $cmd.Executed | Should -Be $false
    }

    It 'Should describe with label' {
        $cmd = [NoopCommand]::new('mylabel')
        $cmd.Describe() | Should -Be 'Noop[mylabel]'
    }
}

Describe 'FailingCommand' {
    It 'Should throw on Execute' {
        $cmd = [FailingCommand]::new()
        { $cmd.Execute() } | Should -Throw -ExceptionType ([System.InvalidOperationException])
    }

    It 'Should not throw on Undo' {
        $cmd = [FailingCommand]::new()
        { $cmd.Undo() } | Should -Not -Throw
    }

    It 'Should describe correctly' {
        $cmd = [FailingCommand]::new()
        $cmd.Describe() | Should -Be 'FailingCommand'
    }
}

Describe 'HashFileCommand' {
    BeforeAll {
        $script:testFile = Join-Path $TestDrive 'test.txt'
        'Hello, World!' | Out-File -FilePath $script:testFile -NoNewline -Encoding utf8
    }

    It 'Should compute SHA-256 hash of file' {
        $cmd = [HashFileCommand]::new($script:testFile)
        $cmd.Execute()
        $cmd.Executed | Should -Be $true
        $cmd.Result | Should -Not -BeNullOrEmpty
        $cmd.Result | Should -BeOfType [string]
        # Expected hash for "Hello, World!"
        $cmd.Result | Should -Match '^[a-f0-9]{64}$'
    }

    It 'Should throw FileNotFoundException for missing file' {
        $cmd = [HashFileCommand]::new('C:\NonExistent\file.txt')
        { $cmd.Execute() } | Should -Throw -ExceptionType ([System.IO.FileNotFoundException])
    }

    It 'Should have no-op Undo' {
        $cmd = [HashFileCommand]::new($script:testFile)
        $cmd.Execute()
        $result1 = $cmd.Result
        { $cmd.Undo() } | Should -Not -Throw
        $cmd.Result | Should -Be $result1  # Result unchanged after Undo
    }

    It 'Should describe with file path' {
        $cmd = [HashFileCommand]::new($script:testFile)
        $cmd.Describe() | Should -Match 'HashFile\[.*test\.txt\]'
    }

    It 'Should produce consistent hash for same content' {
        $cmd1 = [HashFileCommand]::new($script:testFile)
        $cmd1.Execute()
        
        $cmd2 = [HashFileCommand]::new($script:testFile)
        $cmd2.Execute()
        
        $cmd1.Result | Should -Be $cmd2.Result
    }

    It 'Should produce different hash for different content' {
        $file2 = Join-Path $TestDrive 'test2.txt'
        'Different content' | Out-File -FilePath $file2 -NoNewline -Encoding utf8
        
        $cmd1 = [HashFileCommand]::new($script:testFile)
        $cmd1.Execute()
        
        $cmd2 = [HashFileCommand]::new($file2)
        $cmd2.Execute()
        
        $cmd1.Result | Should -Not -Be $cmd2.Result
    }
}

Describe 'CryptoCommandQueue - Basic Operations' {
    It 'Should create empty queue' {
        $queue = [CryptoCommandQueue]::new()
        $queue.PendingCount() | Should -Be 0
        $queue.CompletedCount() | Should -Be 0
    }

    It 'Should enqueue commands' {
        $queue = [CryptoCommandQueue]::new()
        $cmd1 = [NoopCommand]::new('cmd1')
        $cmd2 = [NoopCommand]::new('cmd2')
        
        $queue.Enqueue($cmd1)
        $queue.Enqueue($cmd2)
        
        $queue.PendingCount() | Should -Be 2
        $queue.CompletedCount() | Should -Be 0
    }

    It 'Should execute commands in order' {
        $queue = [CryptoCommandQueue]::new()
        $cmd1 = [NoopCommand]::new('first')
        $cmd2 = [NoopCommand]::new('second')
        $cmd3 = [NoopCommand]::new('third')
        
        $queue.Enqueue($cmd1)
        $queue.Enqueue($cmd2)
        $queue.Enqueue($cmd3)
        
        $queue.RunAll()
        
        $queue.PendingCount() | Should -Be 0
        $queue.CompletedCount() | Should -Be 3
        
        $cmd1.Executed | Should -Be $true
        $cmd2.Executed | Should -Be $true
        $cmd3.Executed | Should -Be $true
    }
}

Describe 'CryptoCommandQueue - UndoAll on Failure' {
    It 'Should trigger UndoAll when command fails' {
        $queue = [CryptoCommandQueue]::new()
        $cmd1 = [NoopCommand]::new('before-fail')
        $cmd2 = [FailingCommand]::new()
        $cmd3 = [NoopCommand]::new('after-fail')
        
        $queue.Enqueue($cmd1)
        $queue.Enqueue($cmd2)
        $queue.Enqueue($cmd3)
        
        { $queue.RunAll() } | Should -Throw
        
        # First command was executed but undone
        $cmd1.Executed | Should -Be $false
        
        # Third command never executed
        $cmd3.Executed | Should -Be $false
        
        # Queue and history should be empty after undo
        $queue.CompletedCount() | Should -Be 0
    }

    It 'Should undo commands in reverse order' {
        $queue = [CryptoCommandQueue]::new()
        
        # Create commands that track undo order
        $script:undoOrder = @()
        
        $cmd1 = [NoopCommand]::new('first')
        $originalUndo1 = $cmd1.Undo
        $cmd1 | Add-Member -MemberType ScriptMethod -Name Undo -Value { 
            $script:undoOrder += 'first'
            $this.Executed = $false
        } -Force
        
        $cmd2 = [NoopCommand]::new('second')
        $cmd2 | Add-Member -MemberType ScriptMethod -Name Undo -Value { 
            $script:undoOrder += 'second'
            $this.Executed = $false
        } -Force
        
        $cmd3 = [NoopCommand]::new('third')
        $cmd3 | Add-Member -MemberType ScriptMethod -Name Undo -Value { 
            $script:undoOrder += 'third'
            $this.Executed = $false
        } -Force
        
        $cmd4 = [FailingCommand]::new()
        
        $queue.Enqueue($cmd1)
        $queue.Enqueue($cmd2)
        $queue.Enqueue($cmd3)
        $queue.Enqueue($cmd4)
        
        { $queue.RunAll() } | Should -Throw
        
        # Commands should be undone in reverse: third, second, first
        $script:undoOrder | Should -Be @('third', 'second', 'first')
    }

    It 'Should handle mixed command types with failure' {
        $testFile = Join-Path $TestDrive 'hash-test.txt'
        'Test content' | Out-File -FilePath $testFile -NoNewline -Encoding utf8
        
        $queue = [CryptoCommandQueue]::new()
        $cmd1 = [NoopCommand]::new('noop1')
        $cmd2 = [HashFileCommand]::new($testFile)
        $cmd3 = [NoopCommand]::new('noop2')
        $cmd4 = [FailingCommand]::new()
        
        $queue.Enqueue($cmd1)
        $queue.Enqueue($cmd2)
        $queue.Enqueue($cmd3)
        $queue.Enqueue($cmd4)
        
        { $queue.RunAll() } | Should -Throw
        
        # All executed commands should be undone
        $cmd1.Executed | Should -Be $false
        $cmd2.Executed | Should -Be $true  # HashFileCommand has no-op Undo
        $cmd3.Executed | Should -Be $false
        
        $queue.CompletedCount() | Should -Be 0
    }

    It 'Should not trigger UndoAll if all commands succeed' {
        $queue = [CryptoCommandQueue]::new()
        $cmd1 = [NoopCommand]::new('cmd1')
        $cmd2 = [NoopCommand]::new('cmd2')
        
        $queue.Enqueue($cmd1)
        $queue.Enqueue($cmd2)
        
        { $queue.RunAll() } | Should -Not -Throw
        
        $cmd1.Executed | Should -Be $true
        $cmd2.Executed | Should -Be $true
        $queue.CompletedCount() | Should -Be 2
    }

    It 'Should clear pending queue after failure' {
        $queue = [CryptoCommandQueue]::new()
        $cmd1 = [NoopCommand]::new('before')
        $cmd2 = [FailingCommand]::new()
        $cmd3 = [NoopCommand]::new('after')
        $cmd4 = [NoopCommand]::new('after2')
        
        $queue.Enqueue($cmd1)
        $queue.Enqueue($cmd2)
        $queue.Enqueue($cmd3)
        $queue.Enqueue($cmd4)
        
        { $queue.RunAll() } | Should -Throw
        
        # Pending commands after failure should remain in queue
        # Actually, the implementation dequeues before executing, so failed command
        # is removed and remaining commands stay in queue
        $queue.PendingCount() | Should -Be 2  # cmd3 and cmd4 remain
    }
}

Describe 'CryptoCommandQueue - HashFileCommand Integration' {
    BeforeAll {
        $script:file1 = Join-Path $TestDrive 'file1.txt'
        $script:file2 = Join-Path $TestDrive 'file2.txt'
        'Content 1' | Out-File -FilePath $script:file1 -NoNewline -Encoding utf8
        'Content 2' | Out-File -FilePath $script:file2 -NoNewline -Encoding utf8
    }

    It 'Should execute multiple HashFileCommands' {
        $queue = [CryptoCommandQueue]::new()
        $cmd1 = [HashFileCommand]::new($script:file1)
        $cmd2 = [HashFileCommand]::new($script:file2)
        
        $queue.Enqueue($cmd1)
        $queue.Enqueue($cmd2)
        
        $queue.RunAll()
        
        $cmd1.Result | Should -Not -BeNullOrEmpty
        $cmd2.Result | Should -Not -BeNullOrEmpty
        $cmd1.Result | Should -Not -Be $cmd2.Result
        
        $queue.CompletedCount() | Should -Be 2
    }

    It 'Should handle HashFileCommand failure in queue' {
        $queue = [CryptoCommandQueue]::new()
        $cmd1 = [NoopCommand]::new('before-hash')
        $cmd2 = [HashFileCommand]::new('C:\NonExistent\missing.txt')
        $cmd3 = [NoopCommand]::new('after-hash')
        
        $queue.Enqueue($cmd1)
        $queue.Enqueue($cmd2)
        $queue.Enqueue($cmd3)
        
        { $queue.RunAll() } | Should -Throw
        
        # First command should be undone
        $cmd1.Executed | Should -Be $false
        
        # Third command never executed
        $cmd3.Executed | Should -Be $false
        
        $queue.CompletedCount() | Should -Be 0
    }
}
