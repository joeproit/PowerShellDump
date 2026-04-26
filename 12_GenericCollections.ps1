<#
.SYNOPSIS
    OOP Reference: Generic Collections in Classes
.DESCRIPTION
    Topic:        Strongly-typed collections, TryGetValue, SortedDictionary
    Category:     Structural
    Agent Task:   Add a GetExpiredKeys([int]$olderThanDays) method that returns
                  string[] of key names not accessed in the last N days.
                  Track last-accessed timestamp per key.
                  Add Pester tests for TryGet returning false on missing key.
    Done Conditions:
      - TryGet returns $false and does not throw on missing key
      - GetExpiredKeys returns correct subset
      - Pester tests pass: Invoke-Pester -Output Detailed
    Non-Scope:
      - No concurrent dictionary (covered in object pool)
#>

class TypedKeyStore {
    hidden [System.Collections.Generic.Dictionary[string, byte[]]]$_keys
    hidden [System.Collections.Generic.List[string]]$_auditLog
    hidden [System.Collections.Generic.Dictionary[string, datetime]]$_lastAccessed

    TypedKeyStore() {
        $this._keys        = [System.Collections.Generic.Dictionary[string,byte[]]]::new()
        $this._auditLog    = [System.Collections.Generic.List[string]]::new()
        $this._lastAccessed = [System.Collections.Generic.Dictionary[string,datetime]]::new()
    }

    [void] Set([string]$name, [byte[]]$key) {
        $this._keys[$name]         = $key
        $this._lastAccessed[$name] = [datetime]::UtcNow
        $this._auditLog.Add("SET $name $(Get-Date -Format u)")
    }

    [byte[]] Get([string]$name) {
        $key = $null
        if (-not $this._keys.TryGetValue($name, [ref]$key)) {
            throw [System.Collections.Generic.KeyNotFoundException]"Key '$name' not found"
        }
        $this._lastAccessed[$name] = [datetime]::UtcNow
        return $key
    }

    [bool] TryGet([string]$name, [ref]$outKey) {
        $result = $this._keys.TryGetValue($name, $outKey)
        if ($result) {
            $this._lastAccessed[$name] = [datetime]::UtcNow
        }
        return $result
    }

    [string[]] GetExpiredKeys([int]$olderThanDays) {
        $cutoffDate = [datetime]::UtcNow.AddDays(-$olderThanDays)
        $expired = [System.Collections.Generic.List[string]]::new()
        
        foreach ($kvp in $this._lastAccessed.GetEnumerator()) {
            if ($kvp.Value -lt $cutoffDate) {
                $expired.Add($kvp.Key)
            }
        }
        
        return $expired.ToArray()
    }

    [string[]] GetNames() { return @($this._keys.Keys) }

    [string[]] GetAuditLog() { return $this._auditLog.ToArray() }
}
