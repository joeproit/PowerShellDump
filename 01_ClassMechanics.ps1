<#
.SYNOPSIS
    OOP Reference: Class Mechanics
.DESCRIPTION
    Topic:        PowerShell Class Mechanics
    Category:     Fundamentals
    Agent Task:   Study, extend, and add Pester tests for each concept below.
                  Do not refactor the examples — extend them.
    Done Conditions:
      - Each class loads without error in PS 7.x
      - Pester tests cover: static ctor fires once, hidden member accessible via code but not Get-Member,
        [void] method produces no pipeline output, load order enforced by dot-source order
      - Tests pass: Invoke-Pester -Output Detailed
    Non-Scope:
      - Do not add GUI, remote, or module-level concerns
      - Do not convert to a module manifest yet
#>

# ---------------------------------------------------------------------------
# 1. Static Constructor / Type Initializer
# ---------------------------------------------------------------------------
# Fires exactly once when the type is first accessed. No parameters allowed.
class CryptoRegistry {
    static [hashtable]$Algorithms
    static [bool]$Initialized

    static CryptoRegistry() {
        [CryptoRegistry]::Algorithms = @{
            'AES-256-GCM'  = [System.Security.Cryptography.AesGcm]
            'AES-256-CBC'  = [System.Security.Cryptography.Aes]
            'SHA-256'      = [System.Security.Cryptography.SHA256]
            'SHA-512'      = [System.Security.Cryptography.SHA512]
            'HMAC-SHA-256' = [System.Security.Cryptography.HMACSHA256]
        }
        [CryptoRegistry]::Initialized = $true
    }

    static [bool] IsSupported([string]$algo) {
        return [CryptoRegistry]::Algorithms.ContainsKey($algo)
    }
}

# ---------------------------------------------------------------------------
# 2. Class Load Order
# ---------------------------------------------------------------------------
# Parent must be defined before child in the same file.
# In multi-file projects: dot-source in dependency order.
class CryptoBase {
    [string]$Algorithm
    CryptoBase([string]$algo) { $this.Algorithm = $algo }
}

class DerivedCrypto : CryptoBase {
    DerivedCrypto() : base('AES-256-GCM') { }
}

# ---------------------------------------------------------------------------
# 3. hidden vs private — hidden is NOT private
# ---------------------------------------------------------------------------
class SecretHolder {
    hidden [string]$_secret = "hidden but reachable"

    [string] GetSecret() { return $this._secret }
}

# Demonstrate: $obj._secret still works from outside the class
# Demonstrate: $obj | Get-Member does NOT show _secret

# ---------------------------------------------------------------------------
# 4. [void] Return — suppresses pipeline output
# ---------------------------------------------------------------------------
class VoidDemo {
    # Without [void]: Write-Host output leaks into the pipeline return value
    [void] SideEffect([string]$msg) {
        Write-Host $msg
    }

    # Without [void] this would return $true to the caller
    [void] MutateBuffer([byte[]]$buffer) {
        for ($i = 0; $i -lt $buffer.Length; $i++) {
            $buffer[$i] = $buffer[$i] -bxor 0xFF
        }
    }

    [int] TypedReturn([int]$a, [int]$b) {
        return $a + $b
    }
}

# ---------------------------------------------------------------------------
# 5. Method Resolution — type coercion behavior
# ---------------------------------------------------------------------------
class OverloadCoercionDemo {
    [string] Identify([string]$x)  { return "string:$x" }
    [string] Identify([byte[]]$x)  { return "bytes:$($x.Length)" }
    [string] Identify([int]$x)     { return "int:$x" }
}

# Usage examples (run interactively or in Pester):
# $d = [OverloadCoercionDemo]::new()
# $d.Identify("hello")        -> string overload
# $d.Identify(42)             -> int overload
# $d.Identify([byte[]]@(1,2)) -> byte[] overload
# $d.Identify($null)          -> THROWS: ambiguous between string and byte[]
# Fix: [string]$null or [byte[]]$null
