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
        switch ($this._profile.CipherAlgorithm) {
            'AES-256-GCM' {
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
            default { throw [System.NotSupportedException]"$($this._profile.CipherAlgorithm) not implemented" }
        }
    }

    [byte[]] Decrypt([hashtable]$pkg) {
        switch ($pkg.Algorithm) {
            'AES-256-GCM' {
                $pt  = [byte[]]::new($pkg.Ciphertext.Length)
                $gcm = [System.Security.Cryptography.AesGcm]::new($pkg.Key)
                $gcm.Decrypt($pkg.Nonce, $pkg.Ciphertext, $pkg.Tag, $pt); $gcm.Dispose()
                return $pt
            }
            default { throw [System.NotSupportedException]"Cannot decrypt: $($pkg.Algorithm)" }
        }
    }

    [byte[]] Hash([byte[]]$data) {
        $h = [System.Security.Cryptography.HashAlgorithm]::Create($this._profile.HashAlgorithm)
        try { return $h.ComputeHash($data) } finally { $h.Dispose() }
    }
}
