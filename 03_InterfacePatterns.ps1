<#
.SYNOPSIS
    OOP Reference: Interface Patterns
.DESCRIPTION
    Topic:        .NET Interface Implementation, Custom Interface Enforcement, Duck Typing
    Category:     Fundamentals
    Agent Task:   Implement ICloneable on CryptoKey. Add a second ICryptoTransform
                  implementation (Base64Transform) and verify it satisfies the contract.
    Done Conditions:
      - ManagedCryptoService.Dispose() called twice does not throw
      - CryptoKey list sorts correctly via IComparable
      - ICryptoTransform.Validate() throws on a stub that does not implement all methods
      - Pester tests pass: Invoke-Pester -Output Detailed
    Non-Scope:
      - No async/await patterns yet
      - No generic interface variants
#>

# ---------------------------------------------------------------------------
# 1. IDisposable — proper two-phase dispose pattern
# ---------------------------------------------------------------------------
class ManagedCryptoService : System.IDisposable {
    hidden [System.Security.Cryptography.Aes]$_aes
    hidden [bool]$_disposed

    ManagedCryptoService() {
        $this._aes = [System.Security.Cryptography.Aes]::Create()
        $this._aes.GenerateKey()
        $this._aes.GenerateIV()
        $this._disposed = $false
    }

    [void] Dispose() {
        $this.Dispose($true)
        [System.GC]::SuppressFinalize($this)
    }

    hidden [void] Dispose([bool]$disposing) {
        if (-not $this._disposed) {
            if ($disposing) { $this._aes.Dispose() }
            $this._disposed = $true
        }
    }

    [byte[]] Encrypt([byte[]]$data) {
        if ($this._disposed) {
            throw [System.ObjectDisposedException]::new($this.GetType().Name)
        }
        $enc = $this._aes.CreateEncryptor()
        try { return $enc.TransformFinalBlock($data, 0, $data.Length) }
        finally { $enc.Dispose() }
    }
}

# ---------------------------------------------------------------------------
# 2. IComparable — sortable CryptoKey by expiry date
# ---------------------------------------------------------------------------
class CryptoKey : System.IComparable, System.ICloneable {
    [string]$Id
    [datetime]$Created
    [datetime]$Expires

    CryptoKey([string]$id, [int]$validDays) {
        $this.Id      = $id
        $this.Created = [datetime]::UtcNow
        $this.Expires = $this.Created.AddDays($validDays)
    }

    [int] CompareTo([object]$other) {
        if ($other -isnot [CryptoKey]) { return 1 }
        return $this.Expires.CompareTo(([CryptoKey]$other).Expires)
    }

    [object] Clone() {
        $clone = [CryptoKey]::new($this.Id, 0)
        $clone.Created = $this.Created
        $clone.Expires = $this.Expires
        return $clone
    }
}

# $keys = @([CryptoKey]::new('a',90), [CryptoKey]::new('b',30), [CryptoKey]::new('c',365))
# $keys | Sort-Object   -> sorted by expiry ascending

# ---------------------------------------------------------------------------
# 3. Custom interface enforcement via abstract base class
# ---------------------------------------------------------------------------
class ICryptoTransform {
    [byte[]] Transform([byte[]]$input)        { throw [System.NotImplementedException]'Transform' }
    [byte[]] InverseTransform([byte[]]$input) { throw [System.NotImplementedException]'InverseTransform' }
    [string] GetAlgorithmId()                 { throw [System.NotImplementedException]'GetAlgorithmId' }

    # Contract validator — call from factory before handing to consumer
    static [void] Validate([ICryptoTransform]$impl) {
        $methods = @('Transform', 'InverseTransform', 'GetAlgorithmId')
        foreach ($m in $methods) {
            try {
                # GetAlgorithmId takes no parameters, others take byte[]
                if ($m -eq 'GetAlgorithmId') {
                    $impl.$m()
                } else {
                    $impl.$m([byte[]]::new(1))
                }
            }
            catch [System.NotImplementedException] {
                throw [System.InvalidOperationException]"$($impl.GetType().Name) must implement $m"
            }
            catch { } # Other exceptions are acceptable — method exists and ran
        }
    }
}

# ---------------------------------------------------------------------------
# 4. Concrete ICryptoTransform: XOR (trivial, for demonstration)
# ---------------------------------------------------------------------------
class XorTransform : ICryptoTransform {
    hidden [byte]$_key

    XorTransform([byte]$key) { $this._key = $key }

    [byte[]] Transform([byte[]]$input) {
        return $input | ForEach-Object { $_ -bxor $this._key }
    }

    [byte[]] InverseTransform([byte[]]$input) {
        return $this.Transform($input)  # XOR is self-inverse
    }

    [string] GetAlgorithmId() { return "XOR-1" }
}

# ---------------------------------------------------------------------------
# 5. Agent Task: Base64Transform — ICryptoTransform implementation
# ---------------------------------------------------------------------------
class Base64Transform : ICryptoTransform {
    
    Base64Transform() { }

    [byte[]] Transform([byte[]]$input) {
        # Transform: bytes -> base64 string -> UTF8 bytes
        $base64String = [System.Convert]::ToBase64String($input)
        return [System.Text.Encoding]::UTF8.GetBytes($base64String)
    }

    [byte[]] InverseTransform([byte[]]$input) {
        # InverseTransform: UTF8 bytes -> base64 string -> original bytes
        $base64String = [System.Text.Encoding]::UTF8.GetString($input)
        return [System.Convert]::FromBase64String($base64String)
    }

    [string] GetAlgorithmId() { 
        return "BASE64-1" 
    }
}

# ---------------------------------------------------------------------------
# 6. Test stubs for contract validation (used by Pester tests)
# ---------------------------------------------------------------------------
class IncompleteTransform : ICryptoTransform { }

class NoTransform : ICryptoTransform {
    [byte[]] InverseTransform([byte[]]$input) { return $input }
    [string] GetAlgorithmId() { return "NONE" }
}

class NoInverse : ICryptoTransform {
    [byte[]] Transform([byte[]]$input) { return $input }
    [string] GetAlgorithmId() { return "NONE" }
}

class NoAlgorithmId : ICryptoTransform {
    [byte[]] Transform([byte[]]$input) { return $input }
    [byte[]] InverseTransform([byte[]]$input) { return $input }
    # GetAlgorithmId() not implemented - inherits NotImplementedException from base
}
