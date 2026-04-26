<#
.SYNOPSIS
    OOP Reference: Key Rotation with Retention Window
.DESCRIPTION
    Topic:        Production key rotation — new key encrypts, old keys retained for decryption
    Category:     Advanced Crypto
    Agent Task:   Add a ReEncrypt([string]$oldKeyId, [byte[]]$ciphertext) method that
                  decrypts with the old key and re-encrypts with the current key.
                  Add Pester tests verifying a key pruned beyond retainCount cannot decrypt.
    Done Conditions:
      - Encrypt uses current key
      - Decrypt works for any retained key
      - Keys beyond retainCount throw CryptographicException on decrypt
      - Pester tests pass: Invoke-Pester -Output Detailed
    Non-Scope:
      - No external KMS integration
#>

class RotatingKeyManager {
    hidden [System.Collections.Generic.Dictionary[string,byte[]]]$_keys
    hidden [System.Collections.Generic.List[string]]$_keyOrder
    hidden [int]$_maxRetained

    RotatingKeyManager([int]$retainCount = 3) {
        $this._keys       = [System.Collections.Generic.Dictionary[string,byte[]]]::new()
        $this._keyOrder   = [System.Collections.Generic.List[string]]::new()
        $this._maxRetained = $retainCount
        $this._GenerateAndActivate()
    }

    hidden [string] _GenerateAndActivate() {
        $id  = "key-$(Get-Date -Format 'yyyyMMddHHmmss')-$([System.Guid]::NewGuid().ToString('N').Substring(0,6))"
        $mat = [byte[]]::new(32)
        [System.Security.Cryptography.RandomNumberGenerator]::Fill($mat)
        $this._keys[$id] = $mat
        $this._keyOrder.Add($id)

        while ($this._keyOrder.Count -gt $this._maxRetained) {
            $oldest = $this._keyOrder[0]
            [System.Array]::Clear($this._keys[$oldest], 0, $this._keys[$oldest].Length)
            $this._keys.Remove($oldest) | Out-Null
            $this._keyOrder.RemoveAt(0)
        }
        return $id
    }

    [string] GetCurrentKeyId() { return $this._keyOrder[$this._keyOrder.Count - 1] }

    [hashtable] Encrypt([byte[]]$plaintext) {
        $kid = $this.GetCurrentKeyId()
        $key = $this._keys[$kid]
        $gcm = [System.Security.Cryptography.AesGcm]::new($key)
        $n   = [byte[]]::new(12); $ct = [byte[]]::new($plaintext.Length); $t = [byte[]]::new(16)
        [System.Security.Cryptography.RandomNumberGenerator]::Fill($n)
        $gcm.Encrypt($n, $plaintext, $ct, $t); $gcm.Dispose()
        return @{ KeyId=$kid; Ciphertext=($n + $t + $ct) }
    }

    [byte[]] Decrypt([string]$keyId, [byte[]]$ciphertext) {
        $key = $null
        if (-not $this._keys.TryGetValue($keyId, [ref]$key)) {
            throw [System.Security.Cryptography.CryptographicException]"Key '$keyId' not available (expired or purged)"
        }
        $nonce = $ciphertext[0..11]; $tag = $ciphertext[12..27]; $body = $ciphertext[28..($ciphertext.Length-1)]
        $pt    = [byte[]]::new($body.Length)
        $gcm   = [System.Security.Cryptography.AesGcm]::new($key)
        $gcm.Decrypt($nonce, $body, $tag, $pt); $gcm.Dispose()
        return $pt
    }

    [void] Rotate() { $this._GenerateAndActivate() }

    [string[]] GetRetainedKeyIds() { return $this._keyOrder.ToArray() }
}
