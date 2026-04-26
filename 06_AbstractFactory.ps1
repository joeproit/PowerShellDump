<#
.SYNOPSIS
    OOP Reference: Abstract Factory Pattern
.DESCRIPTION
    Topic:        Abstract Factory — families of related crypto objects
    Category:     Creational
    Agent Task:   Add a second concrete factory: LegacyCryptoSuiteFactory that uses
                  AES-128-CBC + HMAC-SHA1 + MD5 (deliberately weak — label it legacy).
                  Add a factory selector function that picks factory based on a string
                  ('fips' | 'legacy'). Add Pester tests.
    Done Conditions:
      - SecureChannel works with both factories without modification
      - Factory selector returns correct type
      - Pester tests pass: Invoke-Pester -Output Detailed
    Non-Scope:
      - No real FIPS validation — label is illustrative
#>

class ICipher {
    [byte[]] Seal([byte[]]$pt) { throw [System.NotImplementedException]'Seal' }
    [byte[]] Open([byte[]]$ct) { throw [System.NotImplementedException]'Open' }
}

class ISigner {
    [byte[]] Sign([byte[]]$data)                 { throw [System.NotImplementedException]'Sign' }
    [bool]   Verify([byte[]]$data, [byte[]]$sig) { throw [System.NotImplementedException]'Verify' }
}

class IHasher {
    [byte[]] Hash([byte[]]$data) { throw [System.NotImplementedException]'Hash' }
}

class FipsAesCipher : ICipher {
    hidden [byte[]]$_k
    FipsAesCipher() {
        $this._k = [byte[]]::new(32)
        [System.Security.Cryptography.RandomNumberGenerator]::Fill($this._k)
    }
    [byte[]] Seal([byte[]]$pt) {
        $gcm   = [System.Security.Cryptography.AesGcm]::new($this._k)
        $nonce = [byte[]]::new(12); $ct = [byte[]]::new($pt.Length); $tag = [byte[]]::new(16)
        [System.Security.Cryptography.RandomNumberGenerator]::Fill($nonce)
        $gcm.Encrypt($nonce, $pt, $ct, $tag); $gcm.Dispose()
        return $nonce + $tag + $ct
    }
    [byte[]] Open([byte[]]$ct) {
        $nonce = $ct[0..11]; $tag = $ct[12..27]; $body = $ct[28..($ct.Length-1)]
        $pt    = [byte[]]::new($body.Length)
        $gcm   = [System.Security.Cryptography.AesGcm]::new($this._k)
        $gcm.Decrypt($nonce, $body, $tag, $pt); $gcm.Dispose()
        return $pt
    }
}

class FipsRsaSigner : ISigner {
    hidden [System.Security.Cryptography.RSA]$_rsa
    FipsRsaSigner() { $this._rsa = [System.Security.Cryptography.RSA]::Create(2048) }
    [byte[]] Sign([byte[]]$data) {
        return $this._rsa.SignData($data,
            [System.Security.Cryptography.HashAlgorithmName]::SHA256,
            [System.Security.Cryptography.RSASignaturePadding]::Pss)
    }
    [bool] Verify([byte[]]$data, [byte[]]$sig) {
        return $this._rsa.VerifyData($data, $sig,
            [System.Security.Cryptography.HashAlgorithmName]::SHA256,
            [System.Security.Cryptography.RSASignaturePadding]::Pss)
    }
}

class Sha256Hasher : IHasher {
    [byte[]] Hash([byte[]]$data) {
        $h = [System.Security.Cryptography.SHA256]::Create()
        try { return $h.ComputeHash($data) } finally { $h.Dispose() }
    }
}

class ICryptoSuiteFactory {
    [ICipher]  CreateCipher() { throw [System.NotImplementedException]'CreateCipher' }
    [ISigner]  CreateSigner() { throw [System.NotImplementedException]'CreateSigner' }
    [IHasher]  CreateHasher() { throw [System.NotImplementedException]'CreateHasher' }
}

class FipsCryptoSuiteFactory : ICryptoSuiteFactory {
    [ICipher]  CreateCipher() { return [FipsAesCipher]::new() }
    [ISigner]  CreateSigner() { return [FipsRsaSigner]::new() }
    [IHasher]  CreateHasher() { return [Sha256Hasher]::new() }
}

class SecureChannel {
    hidden [ICipher]$_cipher
    hidden [ISigner]$_signer
    hidden [IHasher]$_hasher

    SecureChannel([ICryptoSuiteFactory]$factory) {
        $this._cipher = $factory.CreateCipher()
        $this._signer = $factory.CreateSigner()
        $this._hasher = $factory.CreateHasher()
    }

    [hashtable] Send([byte[]]$message) {
        $sealed    = $this._cipher.Seal($message)
        $signature = $this._signer.Sign($sealed)
        $hash      = $this._hasher.Hash($message)
        return @{ Sealed=$sealed; Signature=$signature; Hash=$hash }
    }

    [byte[]] Receive([hashtable]$packet) {
        if (-not $this._signer.Verify($packet.Sealed, $packet.Signature)) {
            throw [System.Security.SecurityException]'Signature verification failed'
        }
        return $this._cipher.Open($packet.Sealed)
    }
}
