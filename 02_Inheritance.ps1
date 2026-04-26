<#
.SYNOPSIS
    OOP Reference: Inheritance Deep Dive
.DESCRIPTION
    Topic:        Inheritance, Constructor Chaining, Method Override, Type Checking
    Category:     Fundamentals
    Agent Task:   Add Pester tests. Add a third level of inheritance (GrandchildCrypto).
                  Override Describe() in the grandchild with a call to ([AesService]$this).Describe().
    Done Conditions:
      - Three-level chain loads and instantiates without error
      - $grandchild -is [CryptoBase] returns $true
      - Pester covers: base ctor called, override fires, is-a chain, safe downcast
      - Tests pass: Invoke-Pester -Output Detailed
    Non-Scope:
      - No multiple inheritance attempts
      - No static methods on derived classes yet (covered in factory file)
#>

# ---------------------------------------------------------------------------
# Base class — defines shared state and enforced interface
# ---------------------------------------------------------------------------
class CryptoBase {
    [string]$Algorithm
    [int]$KeyBits
    [datetime]$CreatedAt

    CryptoBase([string]$algo, [int]$bits) {
        $this.Algorithm = $algo
        $this.KeyBits   = $bits
        $this.CreatedAt = [datetime]::UtcNow
    }

    # Abstract-equivalent: derived classes must override
    [byte[]] Encrypt([byte[]]$data) {
        throw [System.NotImplementedException]::new(
            "$($this.GetType().Name) must implement Encrypt()")
    }

    [string] Describe() {
        return "$($this.GetType().Name) | $($this.Algorithm) | $($this.KeyBits)-bit | created $($this.CreatedAt:u)"
    }
}

# ---------------------------------------------------------------------------
# Level 1: AesService — implements Encrypt, chains to base ctor
# ---------------------------------------------------------------------------
class AesService : CryptoBase {
    hidden [byte[]]$_key

    AesService() : base('AES-256-GCM', 256) {
        $this._key = [byte[]]::new(32)
        [System.Security.Cryptography.RandomNumberGenerator]::Fill($this._key)
    }

    AesService([byte[]]$key) : base('AES-256-GCM', $key.Length * 8) {
        if ($key.Length -notin @(16, 24, 32)) {
            throw [System.ArgumentException]'Key must be 128, 192, or 256 bits'
        }
        $this._key = $key
    }

    [byte[]] Encrypt([byte[]]$data) {
        $gcm   = [System.Security.Cryptography.AesGcm]::new($this._key)
        $nonce = [byte[]]::new(12)
        $ct    = [byte[]]::new($data.Length)
        $tag   = [byte[]]::new(16)
        [System.Security.Cryptography.RandomNumberGenerator]::Fill($nonce)
        $gcm.Encrypt($nonce, $data, $ct, $tag)
        $gcm.Dispose()
        return $nonce + $tag + $ct
    }
}

# ---------------------------------------------------------------------------
# Level 2: AuditedAesService — wraps Encrypt with audit, calls base impl
# ---------------------------------------------------------------------------
class AuditedAesService : AesService {
    [System.Collections.Generic.List[string]]$AuditLog

    AuditedAesService() : base() {
        $this.AuditLog = [System.Collections.Generic.List[string]]::new()
    }

    [byte[]] Encrypt([byte[]]$data) {
        $this.AuditLog.Add("ENCRYPT | $(Get-Date -Format u) | $($data.Length) bytes")
        return ([AesService]$this).Encrypt($data)
    }
}

# ---------------------------------------------------------------------------
# Type-checking utilities (use in Pester or interactive sessions)
# ---------------------------------------------------------------------------
# $svc = [AuditedAesService]::new()
# $svc -is [AuditedAesService]   -> $true
# $svc -is [AesService]          -> $true
# $svc -is [CryptoBase]          -> $true
# $svc.GetType().Name            -> AuditedAesService
# $svc.GetType().BaseType.Name   -> AesService
