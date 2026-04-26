BeforeAll {
    . "$PSScriptRoot/17_EventsDelegates.ps1"
}

Describe "CryptoEventEmitter Events" {
    Context "OnKeyRotated Event" {
        It "Should fire OnKeyRotated when key is rotated" {
            $emitter = [CryptoEventEmitter]::new()
            $logger = [EventLogger]::new()
            
            $emitter.OnKeyRotated = $logger.LogKeyRotation
            $emitter.RotateKey()
            
            $logger.Log.Count | Should -Be 1
            $logger.Log[0] | Should -BeLike "KeyRotated: *"
        }

        It "Should pass the new key ID to OnKeyRotated" {
            $emitter = [CryptoEventEmitter]::new()
            $logger = [EventLogger]::new()
            
            $emitter.OnKeyRotated = $logger.LogKeyRotation
            $emitter.RotateKey()
            
            $keyId = $emitter.GetKeyId()
            $logger.Log[0] | Should -Be "KeyRotated: $keyId"
        }

        It "Should support multiple subscribers via Combine" {
            $emitter = [CryptoEventEmitter]::new()
            $logger1 = [EventLogger]::new()
            $logger2 = [EventLogger]::new()
            
            # Create delegates from methods
            $handler1 = [System.Action[string]]{ param($keyId) $logger1.LogKeyRotation($keyId) }
            $handler2 = [System.Action[string]]{ param($keyId) $logger2.LogKeyRotation($keyId) }
            
            # Chain multiple subscribers using System.Delegate.Combine
            $emitter.OnKeyRotated = [System.Delegate]::Combine($handler1, $handler2)
            
            $emitter.RotateKey()
            
            # Both loggers should have recorded the event
            $logger1.Log.Count | Should -Be 1
            $logger2.Log.Count | Should -Be 1
            $logger1.Log[0] | Should -BeLike "KeyRotated: *"
            $logger2.Log[0] | Should -BeLike "KeyRotated: *"
        }

        It "Should allow chaining three subscribers" {
            $emitter = [CryptoEventEmitter]::new()
            $logger1 = [EventLogger]::new()
            $logger2 = [EventLogger]::new()
            $logger3 = [EventLogger]::new()
            
            # Create delegates from methods
            $handler1 = [System.Action[string]]{ param($keyId) $logger1.LogKeyRotation($keyId) }
            $handler2 = [System.Action[string]]{ param($keyId) $logger2.LogKeyRotation($keyId) }
            $handler3 = [System.Action[string]]{ param($keyId) $logger3.LogKeyRotation($keyId) }
            
            # Chain three subscribers using nested Combine calls
            $emitter.OnKeyRotated = [System.Delegate]::Combine(
                [System.Delegate]::Combine($handler1, $handler2),
                $handler3
            )
            
            $emitter.RotateKey()
            
            $logger1.Log.Count | Should -Be 1
            $logger2.Log.Count | Should -Be 1
            $logger3.Log.Count | Should -Be 1
        }
    }

    Context "OnEncrypt Event" {
        It "Should fire OnEncrypt when data is encrypted" {
            $emitter = [CryptoEventEmitter]::new()
            $logger = [EventLogger]::new()
            
            $emitter.OnEncrypt = $logger.LogEncrypt
            $data = [System.Text.Encoding]::UTF8.GetBytes("test")
            $encrypted = $emitter.Encrypt($data)
            
            $logger.Log.Count | Should -Be 1
            $logger.Log[0] | Should -BeLike "Encrypted: * bytes"
        }

        It "Should support multiple subscribers on OnEncrypt" {
            $emitter = [CryptoEventEmitter]::new()
            $logger1 = [EventLogger]::new()
            $logger2 = [EventLogger]::new()
            
            # Create delegates from methods
            $handler1 = [System.Action[byte[]]]{ param($data) $logger1.LogEncrypt($data) }
            $handler2 = [System.Action[byte[]]]{ param($data) $logger2.LogEncrypt($data) }
            
            $emitter.OnEncrypt = [System.Delegate]::Combine($handler1, $handler2)
            
            $data = [System.Text.Encoding]::UTF8.GetBytes("test")
            $encrypted = $emitter.Encrypt($data)
            
            $logger1.Log.Count | Should -Be 1
            $logger2.Log.Count | Should -Be 1
        }
    }

    Context "OnError Event" {
        It "Should fire OnError when Encrypt throws exception" {
            $emitter = [CryptoEventEmitter]::new()
            $logger = [EventLogger]::new()
            
            $emitter.OnError = $logger.LogError
            
            # Pass null to trigger exception
            { $emitter.Encrypt($null) } | Should -Throw
            
            $logger.Log.Count | Should -Be 1
            $logger.Log[0] | Should -BeLike "Error: *"
        }

        It "Should support multiple subscribers on OnError" {
            $emitter = [CryptoEventEmitter]::new()
            $logger1 = [EventLogger]::new()
            $logger2 = [EventLogger]::new()
            
            # Create delegates from methods
            $handler1 = [System.Action[string]]{ param($error) $logger1.LogError($error) }
            $handler2 = [System.Action[string]]{ param($error) $logger2.LogError($error) }
            
            $emitter.OnError = [System.Delegate]::Combine($handler1, $handler2)
            
            # Pass null to trigger exception
            { $emitter.Encrypt($null) } | Should -Throw
            
            $logger1.Log.Count | Should -Be 1
            $logger2.Log.Count | Should -Be 1
            $logger1.Log[0] | Should -BeLike "Error: *"
            $logger2.Log[0] | Should -BeLike "Error: *"
        }
    }

    Context "Multiple Event Types" {
        It "Should fire multiple different events independently" {
            $emitter = [CryptoEventEmitter]::new()
            $logger = [EventLogger]::new()
            
            $emitter.OnKeyRotated = $logger.LogKeyRotation
            $emitter.OnEncrypt = $logger.LogEncrypt
            $emitter.OnError = $logger.LogError
            
            # Trigger key rotation
            $emitter.RotateKey()
            
            # Trigger encrypt
            $data = [System.Text.Encoding]::UTF8.GetBytes("test")
            $encrypted = $emitter.Encrypt($data)
            
            # Trigger error
            { $emitter.Encrypt($null) } | Should -Throw
            
            # Should have 3 log entries
            $logger.Log.Count | Should -Be 3
            $logger.Log[0] | Should -BeLike "KeyRotated: *"
            $logger.Log[1] | Should -BeLike "Encrypted: *"
            $logger.Log[2] | Should -BeLike "Error: *"
        }

        It "Should handle mixed subscribers on multiple events" {
            $emitter = [CryptoEventEmitter]::new()
            $logger1 = [EventLogger]::new()
            $logger2 = [EventLogger]::new()
            
            # Logger1 subscribes to OnKeyRotated
            $handler1 = [System.Action[string]]{ param($keyId) $logger1.LogKeyRotation($keyId) }
            $emitter.OnKeyRotated = $handler1
            
            # Logger1 subscribes to OnEncrypt
            $encHandler1 = [System.Action[byte[]]]{ param($data) $logger1.LogEncrypt($data) }
            $emitter.OnEncrypt = $encHandler1
            
            # Logger2 subscribes to key rotation only using Combine
            $handler2 = [System.Action[string]]{ param($keyId) $logger2.LogKeyRotation($keyId) }
            $emitter.OnKeyRotated = [System.Delegate]::Combine($emitter.OnKeyRotated, $handler2)
            
            $emitter.RotateKey()
            $data = [System.Text.Encoding]::UTF8.GetBytes("test")
            $encrypted = $emitter.Encrypt($data)
            
            # Logger1 should have 2 entries
            $logger1.Log.Count | Should -Be 2
            # Logger2 should have 1 entry
            $logger2.Log.Count | Should -Be 1
        }
    }

    Context "EventLogger Class" {
        It "Should initialize with empty log" {
            $logger = [EventLogger]::new()
            $logger.Log.Count | Should -Be 0
        }

        It "Should use List[string] for log storage" {
            $logger = [EventLogger]::new()
            $logger.Log.GetType().FullName | Should -Be 'System.Collections.Generic.List`1[[System.String, System.Private.CoreLib, Version=8.0.0.0, Culture=neutral, PublicKeyToken=7cec85d7bea7798e]]'
        }

        It "Should format log messages correctly" {
            $logger = [EventLogger]::new()
            
            $logger.LogKeyRotation("abc123")
            $logger.LogEncrypt([byte[]](1,2,3))
            $logger.LogError("Test error")
            
            $logger.Log[0] | Should -Be "KeyRotated: abc123"
            $logger.Log[1] | Should -Be "Encrypted: 3 bytes"
            $logger.Log[2] | Should -Be "Error: Test error"
        }
    }
}
