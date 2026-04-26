<#
.SYNOPSIS
    OOP Reference: Replay Attack Prevention
.DESCRIPTION
    Topic:        Nonce tracking with TTL window to detect replayed messages
    Category:     Advanced Crypto
    Agent Task:   Add a GetWindowStats() method returning current nonce count and
                  window remaining seconds. Add Pester tests verifying:
                  1) First use succeeds, 2) Second use of same nonce throws,
                  3) After window expires, same nonce is accepted again.
    Done Conditions:
      - Replay detected on second Open() with same package
      - Window eviction works (nonces expire after windowSeconds)
      - Pester tests pass: Invoke-Pester -Output Detailed
    Non-Scope:
      - No distributed nonce store — single-process only
#>

class NonceManager {
    hidden [System.Collections.Generic.HashSet[string]]$_seen
    hidden [System.Collections.Generic.Queue[string]]$_eviction
    hidden [int]$_windowSeconds
    hidden [System.Collections.Generic.Dictionary[string,datetime]]$_timestamps

    NonceManager([int]$windowSeconds = 300) {
        $this._windowSeconds = $windowSeconds
        $this._seen          = [System.Collections.Generic.HashSet[string]]::new()
        $this._eviction      = [System.Collections.Generic.Queue[string]]::new()
        $this._timestamps    = [System.Collections.Generic.Dictionary[string,datetime]]::new()
    }

    [bool] CheckAndRecord([string]$nonce) {
        $this._Evict()
        if ($this._seen.Contains($nonce)) { return $false }
        $this._seen.Add($nonce) | Out-Null
        $this._timestamps[$nonce] = [datetime]::UtcNow
        $this._eviction.Enqueue($nonce)
        return $true
    }

    hidden [void] _Evict() {
        $cutoff = [datetime]::UtcNow.AddSeconds(-$this._windowSeconds)
        while ($this._eviction.Count -gt 0) {
            $oldest = $this._eviction.Peek()
            if ($this._timestamps[$oldest] -lt $cutoff) {
                $this._eviction.Dequeue() | Out-Null
                $this._seen.Remove($oldest) | Out-Null
                $this._timestamps.Remove($oldest) | Out-Null
            } else { break }
        }
    }

    [int] WindowedNonceCount() { return $this._seen.Count }
}

class ReplayResistantCrypto {
    hidden [byte[]]$_key
    hidden [NonceManager]$_nonces

    ReplayResistantCrypto([int]$windowSec = 300) {
        $this._key    = [byte[]]::new(32)
        $this._nonces = [NonceManager]::new($windowSec)
        [System.Security.Cryptography.RandomNumberGenerator]::Fill($this._key)
    }

    [hashtable] Seal([byte[]]$plaintext) {
        $nonce = [byte[]]::new(12)
        [System.Security.Cryptography.RandomNumberGenerator]::Fill($nonce)
        $ct  = [byte[]]::new($plaintext.Length); $tag = [byte[]]::new(16)
        $gcm = [System.Security.Cryptography.AesGcm]::new($this._key)
        $gcm.Encrypt($nonce, $plaintext, $ct, $tag); $gcm.Dispose()
        $nonceHex = ($nonce | ForEach-Object { $_.ToString('x2') }) -join ''
        return @{ NonceHex=$nonceHex; Nonce=$nonce; Tag=$tag; Ciphertext=$ct }
    }

    [byte[]] Open([hashtable]$pkg) {
        if (-not $this._nonces.CheckAndRecord($pkg.NonceHex)) {
            throw [System.Security.SecurityException]'Replay attack detected -- nonce already consumed'
        }
        $pt  = [byte[]]::new($pkg.Ciphertext.Length)
        $gcm = [System.Security.Cryptography.AesGcm]::new($this._key)
        $gcm.Decrypt($pkg.Nonce, $pkg.Ciphertext, $pkg.Tag, $pt); $gcm.Dispose()
        return $pt
    }
}
