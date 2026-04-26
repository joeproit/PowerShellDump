BeforeAll {
    . $PSScriptRoot/16_NullObject.ps1
}

Describe 'NullAuditLogger' {
    It 'Never throws on LogEncrypt' {
        $logger = [NullAuditLogger]::new()
        { $logger.LogEncrypt([byte[]]@(1,2,3)) } | Should -Not -Throw
    }
    
    It 'Never throws on LogDecrypt' {
        $logger = [NullAuditLogger]::new()
        { $logger.LogDecrypt(100) } | Should -Not -Throw
    }
    
    It 'Never throws on LogFailure' {
        $logger = [NullAuditLogger]::new()
        { $logger.LogFailure('encrypt', 'test error') } | Should -Not -Throw
    }
    
    It 'Handles null data without throwing' {
        $logger = [NullAuditLogger]::new()
        { $logger.LogEncrypt($null) } | Should -Not -Throw
    }
    
    It 'Handles zero bytes without throwing' {
        $logger = [NullAuditLogger]::new()
        { $logger.LogDecrypt(0) } | Should -Not -Throw
    }
    
    It 'Handles empty strings without throwing' {
        $logger = [NullAuditLogger]::new()
        { $logger.LogFailure('', '') } | Should -Not -Throw
    }
}

Describe 'FileAuditLogger' {
    BeforeEach {
        $script:testFile = Join-Path $TestDrive "audit.log"
    }
    
    It 'Logs encrypt operations' {
        $logger = [FileAuditLogger]::new($script:testFile)
        $logger.LogEncrypt([byte[]]@(1,2,3,4,5))
        
        $content = Get-Content $script:testFile -Raw
        $content | Should -Match 'ENCRYPT\|.*\|5b'
    }
    
    It 'Logs decrypt operations' {
        $logger = [FileAuditLogger]::new($script:testFile)
        $logger.LogDecrypt(128)
        
        $content = Get-Content $script:testFile -Raw
        $content | Should -Match 'DECRYPT\|.*\|128b'
    }
    
    It 'Logs failure operations' {
        $logger = [FileAuditLogger]::new($script:testFile)
        $logger.LogFailure('encrypt', 'key not found')
        
        $content = Get-Content $script:testFile -Raw
        $content | Should -Match 'FAIL\|.*\|encrypt\|key not found'
    }
}

Describe 'BufferingAuditLogger' {
    BeforeEach {
        $script:testFile = Join-Path $TestDrive "buffered-$(Get-Random).log"
    }
    
    It 'Accumulates log entries in memory' {
        $logger = [BufferingAuditLogger]::new()
        $logger.LogEncrypt([byte[]]@(1,2,3))
        $logger.LogDecrypt(64)
        $logger.LogFailure('test', 'error')
        
        # Should not have written to disk yet
        Test-Path $script:testFile | Should -Be $false
    }
    
    It 'Writes all entries on Flush' {
        $logger = [BufferingAuditLogger]::new()
        $logger.LogEncrypt([byte[]]@(1,2,3))
        $logger.LogDecrypt(64)
        $logger.LogFailure('test', 'error')
        
        $logger.Flush($script:testFile)
        
        $content = Get-Content $script:testFile
        $content.Count | Should -Be 3
        $content[0] | Should -Match 'ENCRYPT\|.*\|3b'
        $content[1] | Should -Match 'DECRYPT\|.*\|64b'
        $content[2] | Should -Match 'FAIL\|.*\|test\|error'
    }
    
    It 'Clears buffer after Flush' {
        $logger = [BufferingAuditLogger]::new()
        $logger.LogEncrypt([byte[]]@(1,2,3))
        $logger.Flush($script:testFile)
        
        $firstContent = @(Get-Content $script:testFile | Where-Object { $_ -ne '' })
        $firstContent.Count | Should -Be 1
        
        # Log again and flush to same file
        Remove-Item $script:testFile
        $logger.LogDecrypt(100)
        $logger.Flush($script:testFile)
        
        $secondContent = @(Get-Content $script:testFile | Where-Object { $_ -ne '' })
        $secondContent.Count | Should -Be 1
        $secondContent[0] | Should -Match 'DECRYPT'
    }
    
    It 'Handles empty buffer flush' {
        $logger = [BufferingAuditLogger]::new()
        { $logger.Flush($script:testFile) } | Should -Not -Throw
    }
}

Describe 'CryptoServiceWithAudit' {
    BeforeEach {
        $script:testFile = Join-Path $TestDrive "crypto.log"
    }
    
    It 'Works with NullAuditLogger by default' {
        $service = [CryptoServiceWithAudit]::new()
        $data = [byte[]]@(1,2,3,4,5)
        
        { $result = $service.Encrypt($data) } | Should -Not -Throw
    }
    
    It 'Works with FileAuditLogger' {
        $logger = [FileAuditLogger]::new($script:testFile)
        $service = [CryptoServiceWithAudit]::new($logger)
        $data = [byte[]]@(1,2,3,4,5)
        
        $result = $service.Encrypt($data)
        
        $result | Should -Not -BeNullOrEmpty
        $content = Get-Content $script:testFile -Raw
        $content | Should -Match 'ENCRYPT\|.*\|5b'
    }
    
    It 'Works with BufferingAuditLogger' {
        $logger = [BufferingAuditLogger]::new()
        $service = [CryptoServiceWithAudit]::new($logger)
        $data = [byte[]]@(1,2,3,4,5)
        
        $result = $service.Encrypt($data)
        
        $result | Should -Not -BeNullOrEmpty
        
        # Verify buffer has entry
        $logger.Flush($script:testFile)
        $content = Get-Content $script:testFile -Raw
        $content | Should -Match 'ENCRYPT\|.*\|5b'
    }
    
    It 'Encrypts data correctly' {
        $service = [CryptoServiceWithAudit]::new()
        $data = [byte[]]@(72,101,108,108,111) # "Hello"
        
        $encrypted = $service.Encrypt($data)
        
        # AES-GCM output: 12 byte nonce + 16 byte tag + ciphertext
        $encrypted.Length | Should -Be (12 + 16 + $data.Length)
    }
    
    It 'No null reference exceptions with any logger' {
        $nullLogger = [NullAuditLogger]::new()
        $fileLogger = [FileAuditLogger]::new($script:testFile)
        $bufferLogger = [BufferingAuditLogger]::new()
        
        $service1 = [CryptoServiceWithAudit]::new($nullLogger)
        $service2 = [CryptoServiceWithAudit]::new($fileLogger)
        $service3 = [CryptoServiceWithAudit]::new($bufferLogger)
        
        $data = [byte[]]@(1,2,3)
        
        { $service1.Encrypt($data) } | Should -Not -Throw
        { $service2.Encrypt($data) } | Should -Not -Throw
        { $service3.Encrypt($data) } | Should -Not -Throw
    }
}
