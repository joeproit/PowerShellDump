<#
.SYNOPSIS
    OOP Reference: Mixin / Scriptblock Injection
.DESCRIPTION
    Topic:        Inject cross-cutting behavior via scriptblocks without subclassing
    Category:     Structural
    Agent Task:   Add a timing mixin that wraps Encrypt() and logs elapsed milliseconds
                  to a [System.Collections.Generic.List[hashtable]] on the object.
                  Add Pester tests that verify the hook fires and elapsed > 0.
    Done Conditions:
      - Hook fires before encrypt
      - Timing mixin records elapsed without modifying MixableService
      - Pester tests pass: Invoke-Pester -Output Detailed
    Non-Scope:
      - No async hooks
#>

function Add-TimingMixin {
    param(
        [object]$Target,
        [string[]]$MethodNames
    )
    foreach ($methodName in $MethodNames) {
        $timedScript = [scriptblock]::Create(@"
        param()
        `$sw = [System.Diagnostics.Stopwatch]::StartNew()
        try { `$result = `$this.$methodName(@args); return `$result }
        finally { `$sw.Stop(); Write-Verbose '[$methodName] `$(`$sw.ElapsedMilliseconds)ms' }
"@)
        $Target | Add-Member -MemberType ScriptMethod -Name "${methodName}Timed" -Value $timedScript -Force
    }
}

class MixableService {
    [scriptblock]$OnEncrypt = {}
    [scriptblock]$OnDecrypt = {}
    hidden [byte[]]$_key

    MixableService() {
        $this._key = [byte[]]::new(32)
        [System.Security.Cryptography.RandomNumberGenerator]::Fill($this._key)
    }

    [byte[]] Encrypt([byte[]]$data) {
        & $this.OnEncrypt $data
        $gcm   = [System.Security.Cryptography.AesGcm]::new($this._key)
        $nonce = [byte[]]::new(12); $ct = [byte[]]::new($data.Length); $tag = [byte[]]::new(16)
        [System.Security.Cryptography.RandomNumberGenerator]::Fill($nonce)
        $gcm.Encrypt($nonce, $data, $ct, $tag); $gcm.Dispose()
        return $nonce + $tag + $ct
    }
}

# Inject audit hook:
# $svc = [MixableService]::new()
# $svc.OnEncrypt = { param($d); Write-Host "[AUDIT] $($d.Length) bytes at $(Get-Date -Format u)" }
# $svc.Encrypt([System.Text.Encoding]::UTF8.GetBytes("test"))
