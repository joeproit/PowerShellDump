<#
.SYNOPSIS
    OOP Reference: Null Object Pattern
.DESCRIPTION
    Topic:        Replace null checks with a do-nothing implementation
    Category:     Behavioral
    Agent Task:   Add a BufferingAuditLogger that accumulates log entries in memory
                  and implements Flush([string]$path) to write them to a file.
                  Add Pester tests verifying NullAuditLogger never throws.
    Done Conditions:
      - CryptoServiceWithAudit works with both NullAuditLogger and FileAuditLogger
      - No null reference exceptions possible at call sites
      - Pester tests pass: Invoke-Pester -Output Detailed
    Non-Scope:
      - No remote logging
#>

class IAuditLogger {
    [void] LogEncrypt([byte[]]$data)              { throw [System.NotImplementedException]'LogEncrypt' }
    [void] LogDecrypt([int]$bytes)                { throw [System.NotImplementedException]'LogDecrypt' }
    [void] LogFailure([string]$op, [string]$err)  { throw [System.NotImplementedException]'LogFailure' }
}

class NullAuditLogger : IAuditLogger {
    [void] LogEncrypt([byte[]]$data)             { }
    [void] LogDecrypt([int]$bytes)               { }
    [void] LogFailure([string]$op, [string]$err) { }
}

class FileAuditLogger : IAuditLogger {
    hidden [string]$_path
    FileAuditLogger([string]$logPath) { $this._path = $logPath }
    [void] LogEncrypt([byte[]]$data)    { Add-Content $this._path "ENCRYPT|$(Get-Date -Format u)|$($data.Length)b" }
    [void] LogDecrypt([int]$bytes)      { Add-Content $this._path "DECRYPT|$(Get-Date -Format u)|${bytes}b" }
    [void] LogFailure([string]$op, [string]$err) { Add-Content $this._path "FAIL|$(Get-Date -Format u)|$op|$err" }
}

class CryptoServiceWithAudit {
    hidden [IAuditLogger]$_logger
    hidden [byte[]]$_key

    CryptoServiceWithAudit() {
        $this._logger = [NullAuditLogger]::new()
        $this._key    = [byte[]]::new(32)
        [System.Security.Cryptography.RandomNumberGenerator]::Fill($this._key)
    }

    CryptoServiceWithAudit([IAuditLogger]$logger) {
        $this._logger = $logger
        $this._key    = [byte[]]::new(32)
        [System.Security.Cryptography.RandomNumberGenerator]::Fill($this._key)
    }

    [byte[]] Encrypt([byte[]]$data) {
        $this._logger.LogEncrypt($data)
        $gcm   = [System.Security.Cryptography.AesGcm]::new($this._key)
        $nonce = [byte[]]::new(12); $ct = [byte[]]::new($data.Length); $tag = [byte[]]::new(16)
        [System.Security.Cryptography.RandomNumberGenerator]::Fill($nonce)
        $gcm.Encrypt($nonce, $data, $ct, $tag); $gcm.Dispose()
        return $nonce + $tag + $ct
    }
}
