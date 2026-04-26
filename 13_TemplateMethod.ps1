<#
.SYNOPSIS
    OOP Reference: Template Method Pattern
.DESCRIPTION
    Topic:        Base class defines algorithm skeleton; subclasses fill steps
    Category:     Behavioral
    Agent Task:   Add a third workflow subclass: ZstdAesWorkflow that uses
                  System.IO.Compression.ZLibStream for compression.
                  Add Pester tests verifying the sequence fires in order.
                  Use a [System.Collections.Generic.List[string]] step log in the base class.
    Done Conditions:
      - Execute() sequence cannot be reordered by subclass
      - Step log records Validate->Compress->Encrypt->Sign->Package->Audit in order
      - Pester tests pass: Invoke-Pester -Output Detailed
    Non-Scope:
      - Do not parallelize steps
#>

class CryptoWorkflow {
    hidden [System.Collections.Generic.List[string]]$_stepLog

    CryptoWorkflow() {
        $this._stepLog = [System.Collections.Generic.List[string]]::new()
    }

    # Template method — sequence is invariant
    [hashtable] Execute([byte[]]$plaintext) {
        $validated  = $this._Step('Validate',  { $this.Validate($plaintext) })
        $compressed = $this._Step('Compress',  { $this.Compress($validated) })
        $encrypted  = $this._Step('Encrypt',   { $this.Encrypt($compressed) })
        $signed     = $this._Step('Sign',      { $this.Sign($encrypted) })
        $result     = $this._Step('Package',   { $this.Package($signed) })
        $this._Step('Audit', { $this.Audit($result); $result })
        return $result
    }

    hidden [object] _Step([string]$name, [scriptblock]$action) {
        $this._stepLog.Add($name)
        return & $action
    }

    [string[]] GetStepLog() { return $this._stepLog.ToArray() }

    hidden [byte[]] Validate([byte[]]$data) {
        if ($data.Length -eq 0) { throw [System.ArgumentException]'Empty payload' }
        return $data
    }

    hidden [byte[]] Compress([byte[]]$data)   { return $data }
    hidden [byte[]] Encrypt([byte[]]$data)    { throw [System.NotImplementedException]'Encrypt' }
    hidden [byte[]] Sign([byte[]]$data)       { throw [System.NotImplementedException]'Sign' }
    hidden [hashtable] Package([byte[]]$data) {
        return @{ Payload=$data; Timestamp=[datetime]::UtcNow; Version=1 }
    }
    hidden [void] Audit([hashtable]$result)   { }
}

class GzipAesWorkflow : CryptoWorkflow {
    hidden [byte[]]$_key

    GzipAesWorkflow() : base() {
        $this._key = [byte[]]::new(32)
        [System.Security.Cryptography.RandomNumberGenerator]::Fill($this._key)
    }

    hidden [byte[]] Compress([byte[]]$data) {
        $ms = [System.IO.MemoryStream]::new()
        $gz = [System.IO.Compression.GZipStream]::new($ms,
            [System.IO.Compression.CompressionMode]::Compress)
        $gz.Write($data, 0, $data.Length); $gz.Dispose()
        return $ms.ToArray()
    }

    hidden [byte[]] Encrypt([byte[]]$data) {
        $gcm   = [System.Security.Cryptography.AesGcm]::new($this._key)
        $nonce = [byte[]]::new(12); $ct = [byte[]]::new($data.Length); $tag = [byte[]]::new(16)
        [System.Security.Cryptography.RandomNumberGenerator]::Fill($nonce)
        $gcm.Encrypt($nonce, $data, $ct, $tag); $gcm.Dispose()
        return $nonce + $tag + $ct
    }

    hidden [byte[]] Sign([byte[]]$data) {
        $hmac = [System.Security.Cryptography.HMACSHA256]::new($this._key)
        $mac  = $hmac.ComputeHash($data); $hmac.Dispose()
        return $mac + $data
    }
}
