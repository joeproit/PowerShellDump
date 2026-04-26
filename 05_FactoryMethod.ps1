<#
.SYNOPSIS
    OOP Reference: Factory Method Pattern
.DESCRIPTION
    Topic:        Factory Method — decouple creation from usage
    Category:     Creational
    Agent Task:   Add a 'ChaCha20' branch to CryptoAlgorithmFactory.Create() that
                  throws NotSupportedException with a clear message. Add Pester tests
                  covering: correct type returned, unknown algo throws ArgumentException,
                  keyed overload sets key correctly.
    Done Conditions:
      - Factory returns correct concrete type for each supported algo string
      - Unknown algo throws System.ArgumentException
      - Pester tests pass: Invoke-Pester -Output Detailed
    Non-Scope:
      - Do not add runtime plugin loading
#>

class CryptoAlgorithm {
    [string]$Name
    CryptoAlgorithm([string]$name) { $this.Name = $name }

    [byte[]] Encrypt([byte[]]$data) {
        throw [System.NotImplementedException]'Encrypt'
    }
}

class AesCryptoAlgorithm : CryptoAlgorithm {
    hidden [System.Security.Cryptography.AesGcm]$_gcm
    hidden [byte[]]$_key

    AesCryptoAlgorithm([byte[]]$key) : base('AES-256-GCM') {
        $this._key = $key
        $this._gcm = [System.Security.Cryptography.AesGcm]::new($key)
    }

    [byte[]] Encrypt([byte[]]$data) {
        $nonce = [byte[]]::new(12)
        $ct    = [byte[]]::new($data.Length)
        $tag   = [byte[]]::new(16)
        [System.Security.Cryptography.RandomNumberGenerator]::Fill($nonce)
        $this._gcm.Encrypt($nonce, $data, $ct, $tag)
        return $nonce + $tag + $ct
    }

    [byte[]] GetKey() { return $this._key }
}

class CryptoAlgorithmFactory {
    static [CryptoAlgorithm] Create([string]$algorithmName) {
        $upper = $algorithmName.ToUpper()
        if ($upper -eq 'AES-256-GCM') {
            $key = [byte[]]::new(32)
            [System.Security.Cryptography.RandomNumberGenerator]::Fill($key)
            return [AesCryptoAlgorithm]::new($key)
        }
        elseif ($upper -eq 'CHACHA20') {
            throw [System.NotSupportedException]"ChaCha20 is not yet implemented in this library"
        }
        else {
            throw [System.ArgumentException]"Unknown algorithm: $algorithmName"
        }
    }

    static [CryptoAlgorithm] Create([string]$algorithmName, [byte[]]$key) {
        $upper = $algorithmName.ToUpper()
        if ($upper -eq 'AES-256-GCM') {
            return [AesCryptoAlgorithm]::new($key)
        }
        elseif ($upper -eq 'CHACHA20') {
            throw [System.NotSupportedException]"ChaCha20 is not yet implemented in this library"
        }
        else {
            throw [System.ArgumentException]"Key overload not supported for: $algorithmName"
        }
    }
}

#region Agent Task Implementation
<#
    Agent Task: Add 'ChaCha20' branch to CryptoAlgorithmFactory.Create()
    
    Implementation Notes:
    - Added 'CHACHA20' case to both Create() overloads
    - Throws NotSupportedException with clear message indicating it's not yet implemented
    - Case-insensitive matching via ToUpper() ensures 'ChaCha20', 'chacha20', 'CHACHA20' all work
    - Unknown algorithms still throw ArgumentException as per existing behavior
#>
#endregion
