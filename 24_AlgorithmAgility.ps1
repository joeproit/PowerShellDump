<#
.SYNOPSIS
    OOP Reference: Algorithm Agility
.DESCRIPTION
    Topic:        Swap crypto primitives via config without changing call sites
    Category:     Advanced Crypto
    Agent Task:   Add a second CryptoProfile: Fips140Profile with AES-256-GCM,
                  SHA-384, PBKDF2-SHA256 at 310000 iterations (NIST 2024 floor).
                  Add a static ProfileFactory that returns profiles by name string.
                  Add Pester tests verifying Hash() uses the profile's HashAlgorithm.
    Done Conditions:
      - Swapping the profile at construction changes all algorithmic behavior
      - Profile version is stored in the encrypted package for future decryption
      - Pester tests pass: Invoke-Pester -Output Detailed
    Non-Scope:
      - Do not implement ChaCha20 — stub with NotSupportedException
#>

class CryptoProfile {
    [string]$CipherAlgorithm = 'AES-256-GCM'
    [string]$HashAlgorithm   = 'SHA-256'
    [string]$KdfAlgorithm    = 'PBKDF2-SHA256'
    [int]$KdfIterations      = 200000
    [int]$CipherKeyBits      = 256
    [int]$NonceBytes         = 12
    [int]$TagBytes           = 16
    [string]$Version         = '1'
}

class AgileEncryptor {
    hidden [CryptoProfile]$_profile

    AgileEncryptor([CryptoProfile]$profile) { $this._profile = $profile }

    [hashtable] Encrypt([byte[]]$plaintext) {
        if ($this._profile.CipherAlgorithm -eq 'AES-256-GCM') {
            $key   = [byte[]]::new($this._profile.CipherKeyBits / 8)
            [System.Security.Cryptography.RandomNumberGenerator]::Fill($key)
            $gcm   = [System.Security.Cryptography.AesGcm]::new($key)
            $nonce = [byte[]]::new($this._profile.NonceBytes)
            $ct    = [byte[]]::new($plaintext.Length)
            $tag   = [byte[]]::new($this._profile.TagBytes)
            [System.Security.Cryptography.RandomNumberGenerator]::Fill($nonce)
            $gcm.Encrypt($nonce, $plaintext, $ct, $tag); $gcm.Dispose()
            return @{
                Profile    = $this._profile.Version
                Algorithm  = $this._profile.CipherAlgorithm
                Key        = $key; Nonce=$nonce; Tag=$tag; Ciphertext=$ct
            }
        }
        else {
            throw [System.NotSupportedException]"$($this._profile.CipherAlgorithm) not implemented"
        }
    }

    [byte[]] Decrypt([hashtable]$pkg) {
        if ($pkg.Algorithm -eq 'AES-256-GCM') {
            $pt  = [byte[]]::new($pkg.Ciphertext.Length)
            $gcm = [System.Security.Cryptography.AesGcm]::new($pkg.Key)
            $gcm.Decrypt($pkg.Nonce, $pkg.Ciphertext, $pkg.Tag, $pt); $gcm.Dispose()
            return $pt
        }
        else {
            throw [System.NotSupportedException]"Cannot decrypt: $($pkg.Algorithm)"
        }
    }

    [byte[]] Hash([byte[]]$data) {
        if ($null -eq $data) {
            $data = [byte[]]::new(0)
        }

        $h = $null
        switch ($this._profile.HashAlgorithm.ToUpperInvariant()) {
            'SHA-256' { $h = [System.Security.Cryptography.SHA256]::Create() }
            'SHA256'  { $h = [System.Security.Cryptography.SHA256]::Create() }
            'SHA-384' { $h = [System.Security.Cryptography.SHA384]::Create() }
            'SHA384'  { $h = [System.Security.Cryptography.SHA384]::Create() }
            default   { $h = [System.Security.Cryptography.HashAlgorithm]::Create($this._profile.HashAlgorithm) }
        }

        try { return $h.ComputeHash($data) } finally { $h.Dispose() }
    }
}

class Fips140Profile : CryptoProfile {
    Fips140Profile() {
        $this.CipherAlgorithm = 'AES-256-GCM'
        $this.HashAlgorithm   = 'SHA-384'
        $this.KdfAlgorithm    = 'PBKDF2-SHA256'
        $this.KdfIterations   = 310000
        $this.CipherKeyBits   = 256
        $this.NonceBytes      = 12
        $this.TagBytes        = 16
        $this.Version         = 'FIPS140'
    }
}

class ProfileFactory {
    static [CryptoProfile] Create([string]$name) {
        if ([string]::IsNullOrWhiteSpace($name)) {
            throw [System.ArgumentException]'Profile name is required'
        }

        $normalized = $name.Trim().ToUpperInvariant()
        if ($normalized -in @('DEFAULT', 'CRYPTOPROFILE', 'V1', '1')) {
            return [CryptoProfile]::new()
        }
        elseif ($normalized -in @('FIPS140', 'FIPS140PROFILE', 'FIPS140-2024', 'FIPS')) {
            return [Fips140Profile]::new()
        }
        else {
            throw [System.ArgumentException]"Unknown profile: $name"
        }
    }
}

#region Agent Task Implementation
# Swappable profile set added below the base classes so callers can change
# hash/KDF settings without touching encrypt/decrypt call sites.
#endregion
