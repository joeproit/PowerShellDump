<#
.SYNOPSIS
    OOP Reference: Events and Delegates
.DESCRIPTION
    Topic:        System.Action and System.Func delegates as event hooks in PS classes
    Category:     Behavioral
    Agent Task:   Add an OnKeyRotated event that receives the new key ID as a string.
                  Add a subscriber that writes to a [System.Collections.Generic.List[string]] log.
                  Add Pester tests verifying events fire and can have multiple subscribers.
    Done Conditions:
      - Multiple subscribers can be chained via += on the Action property
      - OnError fires on Encrypt exception
      - Pester tests pass: Invoke-Pester -Output Detailed
    Non-Scope:
      - No .NET EventHandler pattern (that requires Add/Remove methods not supported in PS classes)
#>

class CryptoEventEmitter {
    [System.Action[byte[]]]$OnEncrypt
    [System.Action[byte[]]]$OnDecrypt
    [System.Action[string]]$OnError
    [System.Action[string]]$OnKeyRotated  # receives new key ID
    hidden [byte[]]$_key
    hidden [string]$_keyId

    CryptoEventEmitter() {
        $this._key        = [byte[]]::new(32)
        $this._keyId      = [System.Guid]::NewGuid().ToString('N').Substring(0,8)
        [System.Security.Cryptography.RandomNumberGenerator]::Fill($this._key)
        # No-op default handlers
        $this.OnEncrypt    = [System.Action[byte[]]]{}
        $this.OnDecrypt    = [System.Action[byte[]]]{}
        $this.OnError      = [System.Action[string]]{}
        $this.OnKeyRotated = [System.Action[string]]{}
    }

    [byte[]] Encrypt([byte[]]$data) {
        try {
            $gcm   = [System.Security.Cryptography.AesGcm]::new($this._key)
            $nonce = [byte[]]::new(12); $ct = [byte[]]::new($data.Length); $tag = [byte[]]::new(16)
            [System.Security.Cryptography.RandomNumberGenerator]::Fill($nonce)
            $gcm.Encrypt($nonce, $data, $ct, $tag); $gcm.Dispose()
            $result = $nonce + $tag + $ct
            $this.OnEncrypt.Invoke($result)
            return $result
        } catch {
            $this.OnError.Invoke($_.ToString())
            throw
        }
    }

    [void] RotateKey() {
        [System.Security.Cryptography.RandomNumberGenerator]::Fill($this._key)
        $this._keyId = [System.Guid]::NewGuid().ToString('N').Substring(0,8)
        $this.OnKeyRotated.Invoke($this._keyId)
    }

    [string] GetKeyId() { return $this._keyId }
}
