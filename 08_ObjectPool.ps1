<#
.SYNOPSIS
    OOP Reference: Object Pooling
.DESCRIPTION
    Topic:        Pool expensive crypto objects (RSA) for reuse
    Category:     Creational
    Agent Task:   Add a Stats() method that returns PoolDepth, TotalCreated, TotalRented, TotalReturned.
                  Add a thread-safe version comment block explaining why ConcurrentQueue is used.
                  Add Pester tests: rent all, verify pool empty, return all, verify pool refilled.
    Done Conditions:
      - Pool pre-warms correctly
      - Rent/Return cycle works without error
      - Drain() disposes all instances
      - Pester tests pass: Invoke-Pester -Output Detailed
    Non-Scope:
      - No actual thread-safety tests (requires runspaces, out of scope here)
#>

class RsaPool {
    hidden [System.Collections.Concurrent.ConcurrentQueue[System.Security.Cryptography.RSA]]$_pool
    hidden [int]$_keySize
    hidden [int]$_maxSize
    hidden [int]$_created
    hidden [int]$_rented
    hidden [int]$_returned

    RsaPool([int]$keySize, [int]$poolSize) {
        $this._keySize  = $keySize
        $this._maxSize  = $poolSize
        $this._created  = 0
        $this._rented   = 0
        $this._returned = 0
        $this._pool     = [System.Collections.Concurrent.ConcurrentQueue[System.Security.Cryptography.RSA]]::new()
        $this._Warmup($poolSize)
    }

    hidden [void] _Warmup([int]$count) {
        for ($i = 0; $i -lt $count; $i++) {
            $rsa = [System.Security.Cryptography.RSA]::Create($this._keySize)
            $this._pool.Enqueue($rsa)
            $this._created++
        }
    }

    [System.Security.Cryptography.RSA] Rent() {
        $rsa = $null
        $this._rented++
        if ($this._pool.TryDequeue([ref]$rsa)) { return $rsa }
        Write-Warning "[RsaPool] Pool exhausted — creating on demand"
        $this._created++
        return [System.Security.Cryptography.RSA]::Create($this._keySize)
    }

    [void] Return([System.Security.Cryptography.RSA]$rsa) {
        $this._returned++
        if ($this._pool.Count -lt $this._maxSize) {
            $this._pool.Enqueue($rsa)
        } else {
            $rsa.Dispose()
        }
    }

    [void] Drain() {
        $rsa = $null
        while ($this._pool.TryDequeue([ref]$rsa)) { $rsa.Dispose() }
    }

    [hashtable] Stats() {
        return @{
            PoolDepth    = $this._pool.Count
            TotalCreated = $this._created
            TotalRented  = $this._rented
            TotalReturned= $this._returned
            MaxSize      = $this._maxSize
        }
    }
}

<#
.NOTES
    Thread Safety with ConcurrentQueue
    ===================================
    This implementation uses System.Collections.Concurrent.ConcurrentQueue for thread-safe
    object pooling without explicit locks. Key benefits:
    
    1. Lock-Free Operations: TryDequeue/Enqueue use atomic CAS (Compare-And-Swap) operations
       internally, avoiding the overhead of Monitor.Enter/Exit or lock statements.
    
    2. Non-Blocking: Multiple threads can rent/return simultaneously without blocking each other
       (except during brief CAS retries on contention).
    
    3. FIFO Ordering: Objects are reused in the order they were returned, improving cache locality
       and predictable behavior under load.
    
    4. Safe Count Reading: The .Count property is thread-safe for reads (though it may be stale
       by the time you use it in a multi-threaded scenario).
    
    Trade-offs:
    - Statistics (_rented, _returned, _created) use simple ++ which is NOT atomic. For accurate
      multi-threaded stats, use [System.Threading.Interlocked]::Increment() instead.
    - No fairness guarantees: under heavy contention, some threads may be starved.
    
    Alternative: For bounded pools with blocking behavior, consider using BlockingCollection
    with a maximum capacity, which will block Rent() callers when the pool is exhausted.
#>

# Usage pattern — always use try/finally to guarantee return:
# $pool = [RsaPool]::new(2048, 5)
# $rsa  = $pool.Rent()
# try {
#     $sig = $rsa.SignData([byte[]]@(1,2,3),
#         [System.Security.Cryptography.HashAlgorithmName]::SHA256,
#         [System.Security.Cryptography.RSASignaturePadding]::Pss)
# } finally {
#     $pool.Return($rsa)
# }
