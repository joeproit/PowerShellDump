<#
.SYNOPSIS
    OOP Reference: Composition vs Inheritance
.DESCRIPTION
    Topic:        Prefer composition (has-a) over inheritance (is-a)
    Category:     Structural
    Agent Task:   Add a LoggingSecureChannel that wraps SecureChannel and logs
                  Send/Receive calls. Use composition, not inheritance.
                  Add Pester tests that swap the cipher implementation and verify
                  SecureChannel still works without modification.
    Done Conditions:
      - SecureChannel has no direct reference to FipsAesCipher
      - Swapping cipher at construction produces correct behavior
      - Pester tests pass: Invoke-Pester -Output Detailed
    Non-Scope:
      - Do not add network transport
#>

# Interfaces (reuse from 06_AbstractFactory if dot-sourced, or redefine here for standalone use)
class ICipher2 {
    [byte[]] Seal([byte[]]$pt) { throw [System.NotImplementedException]'Seal' }
    [byte[]] Open([byte[]]$ct) { throw [System.NotImplementedException]'Open' }
}

class ISigner2 {
    [byte[]] Sign([byte[]]$data)                 { throw [System.NotImplementedException]'Sign' }
    [bool]   Verify([byte[]]$data, [byte[]]$sig) { throw [System.NotImplementedException]'Verify' }
}

# Composition-based SecureChannel — injected dependencies, not inherited
class ComposedSecureChannel {
    hidden [ICipher2]$_cipher
    hidden [ISigner2]$_signer
    [string]$PeerId

    ComposedSecureChannel([ICipher2]$cipher, [ISigner2]$signer, [string]$peerId) {
        $this._cipher = $cipher
        $this._signer = $signer
        $this.PeerId  = $peerId
    }

    [hashtable] Send([byte[]]$message) {
        $sealed = $this._cipher.Seal($message)
        $sig    = $this._signer.Sign($sealed)
        return @{ Sealed=$sealed; Signature=$sig; Peer=$this.PeerId }
    }

    [byte[]] Receive([hashtable]$packet) {
        if (-not $this._signer.Verify($packet.Sealed, $packet.Signature)) {
            throw [System.Security.SecurityException]'Signature verification failed'
        }
        return $this._cipher.Open($packet.Sealed)
    }
}

# ======== Agent Task Implementation ========

# Concrete cipher implementations (no FIPS reference in SecureChannel)
class AesGcmCipher : ICipher2 {
    hidden [byte[]]$_k
    AesGcmCipher() {
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
        $nonce = $ct[0..11]; $tag = $ct[12..27]
        if ($ct.Length -gt 28) {
            $body = $ct[28..($ct.Length-1)]
        } else {
            $body = [byte[]]@()
        }
        $pt    = [byte[]]::new($body.Length)
        $gcm   = [System.Security.Cryptography.AesGcm]::new($this._k)
        $gcm.Decrypt($nonce, $body, $tag, $pt); $gcm.Dispose()
        return $pt
    }
}

# Alternative cipher implementation (AES-CBC)
class AesCbcCipher : ICipher2 {
    hidden [byte[]]$_k
    AesCbcCipher() {
        $this._k = [byte[]]::new(32)
        [System.Security.Cryptography.RandomNumberGenerator]::Fill($this._k)
    }
    [byte[]] Seal([byte[]]$pt) {
        $aes = [System.Security.Cryptography.Aes]::Create()
        try {
            $aes.KeySize = 256
            $aes.Key = $this._k
            $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
            $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
            $aes.GenerateIV()
            $iv = $aes.IV
            $encryptor = $aes.CreateEncryptor()
            $ct = $encryptor.TransformFinalBlock($pt, 0, $pt.Length)
            $encryptor.Dispose()
            return $iv + $ct
        } finally {
            $aes.Dispose()
        }
    }
    [byte[]] Open([byte[]]$ct) {
        $iv = $ct[0..15]
        if ($ct.Length -gt 16) {
            $body = $ct[16..($ct.Length-1)]
        } else {
            $body = [byte[]]@()
        }
        $aes = [System.Security.Cryptography.Aes]::Create()
        try {
            $aes.KeySize = 256
            $aes.Key = $this._k
            $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
            $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
            $aes.IV = $iv
            $decryptor = $aes.CreateDecryptor()
            $pt = $decryptor.TransformFinalBlock($body, 0, $body.Length)
            $decryptor.Dispose()
            return $pt
        } finally {
            $aes.Dispose()
        }
    }
}

# RSA-based signer
class RsaSigner : ISigner2 {
    hidden [System.Security.Cryptography.RSA]$_rsa
    RsaSigner() { $this._rsa = [System.Security.Cryptography.RSA]::Create(2048) }
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

# HMAC-based signer
class HmacSigner : ISigner2 {
    hidden [byte[]]$_k
    HmacSigner() {
        $this._k = [byte[]]::new(32)
        [System.Security.Cryptography.RandomNumberGenerator]::Fill($this._k)
    }
    [byte[]] Sign([byte[]]$data) {
        $hmac = [System.Security.Cryptography.HMACSHA256]::new($this._k)
        try { return $hmac.ComputeHash($data) } finally { $hmac.Dispose() }
    }
    [bool] Verify([byte[]]$data, [byte[]]$sig) {
        $hmac = [System.Security.Cryptography.HMACSHA256]::new($this._k)
        try {
            $computed = $hmac.ComputeHash($data)
            if ($computed.Length -ne $sig.Length) { return $false }
            $result = 0
            for ($i = 0; $i -lt $computed.Length; $i++) {
                $result = $result -bor ($computed[$i] -bxor $sig[$i])
            }
            return $result -eq 0
        } finally {
            $hmac.Dispose()
        }
    }
}

# LoggingSecureChannel — uses composition to wrap SecureChannel
class LoggingSecureChannel {
    hidden [ComposedSecureChannel]$_channel
    hidden [System.Collections.Generic.List[string]]$_log
    
    LoggingSecureChannel([ICipher2]$cipher, [ISigner2]$signer, [string]$peerId) {
        $this._channel = [ComposedSecureChannel]::new($cipher, $signer, $peerId)
        $this._log = [System.Collections.Generic.List[string]]::new()
    }
    
    [hashtable] Send([byte[]]$message) {
        $this._log.Add("Send: $($message.Length) bytes to $($this._channel.PeerId)")
        return $this._channel.Send($message)
    }
    
    [byte[]] Receive([hashtable]$packet) {
        $this._log.Add("Receive: from $($packet.Peer)")
        return $this._channel.Receive($packet)
    }
    
    [string[]] GetLog() {
        return $this._log.ToArray()
    }
    
    [void] ClearLog() {
        $this._log.Clear()
    }
}
