<#
.SYNOPSIS
    OOP Reference: Builder Pattern
.DESCRIPTION
    Topic:        Fluent multi-step object construction
    Category:     Creational
    Agent Task:   Add a WithEcdhKeyExchange() method to the builder that sets Algorithm
                  to 'ECDH-P256' and KeyBits to 256. Add validation that ECDH requires
                  KeyBits == 256. Add Pester tests covering the fluent chain and validation failures.
    Done Conditions:
      - Fluent chain builds a valid CryptoConfig
      - Build() throws on invalid config (iterations < 10000, bad key size)
      - Pester tests pass: Invoke-Pester -Output Detailed
    Non-Scope:
      - Do not implement actual ECDH crypto — config only
#>

class CryptoConfig {
    [string]$Algorithm       = 'AES-256-GCM'
    [int]$KeyBits            = 256
    [int]$NonceBits          = 96
    [int]$TagBits            = 128
    [bool]$AuditEnabled      = $false
    [int]$MaxOpsPerMinute    = 1000
    [string]$KeyDerivation   = 'PBKDF2-SHA256'
    [int]$KdfIterations      = 100000
    [byte[]]$StaticKey       = $null
    [string]$Version         = '1'

    [string] ToString() {
        return "[$($this.Algorithm)] key=$($this.KeyBits)b kdf=$($this.KeyDerivation) iter=$($this.KdfIterations) audit=$($this.AuditEnabled)"
    }
}

class CryptoConfigBuilder {
    hidden [CryptoConfig]$_config

    CryptoConfigBuilder() { $this._config = [CryptoConfig]::new() }

    [CryptoConfigBuilder] UseAesGcm([int]$keyBits = 256) {
        $this._config.Algorithm = 'AES-256-GCM'
        $this._config.KeyBits   = $keyBits
        return $this
    }

    [CryptoConfigBuilder] WithAudit() {
        $this._config.AuditEnabled = $true
        return $this
    }

    [CryptoConfigBuilder] WithRateLimit([int]$opsPerMinute) {
        $this._config.MaxOpsPerMinute = $opsPerMinute
        return $this
    }

    [CryptoConfigBuilder] WithPbkdf2([int]$iterations) {
        $this._config.KeyDerivation = 'PBKDF2-SHA256'
        $this._config.KdfIterations = $iterations
        return $this
    }

    [CryptoConfigBuilder] WithStaticKey([byte[]]$key) {
        if ($key.Length -notin @(16, 24, 32)) {
            throw [System.ArgumentException]'Key must be 128/192/256-bit'
        }
        $this._config.StaticKey = $key
        return $this
    }

    [CryptoConfig] Build() {
        if ($this._config.KdfIterations -lt 10000) {
            throw [System.InvalidOperationException]'PBKDF2 iterations too low (min 10000)'
        }
        if ($this._config.KeyBits -notin @(128, 192, 256)) {
            throw [System.InvalidOperationException]"Invalid key size: $($this._config.KeyBits)"
        }
        return $this._config
    }
}

# Usage:
# $config = [CryptoConfigBuilder]::new()
#     .UseAesGcm(256)
#     .WithAudit()
#     .WithRateLimit(500)
#     .WithPbkdf2(200000)
#     .Build()
