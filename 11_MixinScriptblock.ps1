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
        $timedScript = {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            try { 
                $result = $this.$methodName.Invoke($args)
                return $result 
            }
            finally { 
                $sw.Stop()
                Write-Verbose "[$methodName] $($sw.ElapsedMilliseconds)ms"
            }
        }.GetNewClosure()
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

# ================================================================================
# Agent Task: Timing Mixin Implementation
# ================================================================================

<#
.SYNOPSIS
    Add timing mixin that wraps Encrypt() and logs elapsed milliseconds
.DESCRIPTION
    Demonstrates scriptblock injection for cross-cutting timing behavior:
    - Hook fires before encrypt operation (via OnEncrypt scriptblock)
    - Records elapsed milliseconds to a List<hashtable> on the object
    - Does not modify MixableService class definition
    - Uses Add-Member to inject TimingLog property and wrapped method
#>

function Add-EncryptTimingMixin {
    <#
    .SYNOPSIS
        Inject timing behavior into MixableService.Encrypt() method
    .PARAMETER Target
        The MixableService instance to enhance with timing
    .EXAMPLE
        $svc = [MixableService]::new()
        Add-EncryptTimingMixin -Target $svc
        $svc.EncryptTimed([System.Text.Encoding]::UTF8.GetBytes("test"))
        $svc.TimingLog # Shows elapsed milliseconds
    #>
    param(
        [Parameter(Mandatory)]
        [MixableService]$Target
    )
    
    # Add TimingLog property if not already present
    if (-not ($Target.PSObject.Properties.Name -contains 'TimingLog')) {
        $timingLog = [System.Collections.Generic.List[hashtable]]::new()
        $Target | Add-Member -MemberType NoteProperty -Name 'TimingLog' -Value $timingLog -Force
    }
    
    # Add wrapped EncryptTimed method using scriptblock
    # This method handles both timing AND firing the OnEncrypt hook
    $timedEncryptScript = {
        param([byte[]]$data)
        
        # Start timing
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        
        # Call original Encrypt (which will fire the OnEncrypt hook)
        $result = $this.Encrypt($data)
        
        # Stop timing and record to log
        $sw.Stop()
        $entry = @{
            Timestamp = [DateTime]::UtcNow
            Method = 'Encrypt'
            ElapsedMs = $sw.ElapsedMilliseconds
            DataSize = $data.Length
        }
        if ($this.PSObject.Properties.Name -contains 'TimingLog') {
            $this.TimingLog.Add($entry)
        }
        
        return $result
    }
    
    $Target | Add-Member -MemberType ScriptMethod -Name 'EncryptTimed' -Value $timedEncryptScript -Force
}
