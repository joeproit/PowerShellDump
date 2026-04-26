<#
.SYNOPSIS
    OOP Reference: State Machine — Key Lifecycle
.DESCRIPTION
    Topic:        Enum-driven state machine with invariant transition enforcement
    Category:     Behavioral
    Agent Task:   Add a Suspend() transition from Active -> Suspended and
                  a Resume() transition from Suspended -> Active.
                  Add Pester tests for all illegal transitions (should throw).
    Done Conditions:
      - All illegal transitions throw InvalidOperationException
      - Destroy() zeroes key material
      - History log records every transition
      - Pester tests pass: Invoke-Pester -Output Detailed
    Non-Scope:
      - No persistence of state to disk
#>

enum KeyState { Generated; Active; Suspended; Rotated; Revoked; Destroyed }

class CryptoKeyLifecycle {
    [string]$KeyId
    [KeyState]$State
    [datetime]$CreatedAt
    [datetime]$ActivatedAt
    [datetime]$RotatedAt
    [datetime]$RevokedAt
    hidden [byte[]]$_material
    hidden [System.Collections.Generic.List[string]]$_history

    CryptoKeyLifecycle([string]$keyId) {
        $this.KeyId     = $keyId
        $this.State     = [KeyState]::Generated
        $this.CreatedAt = [datetime]::UtcNow
        $this._history  = [System.Collections.Generic.List[string]]::new()
        $this._material = [byte[]]::new(32)
        [System.Security.Cryptography.RandomNumberGenerator]::Fill($this._material)
        $this._log('Created in state Generated')
    }

    [void] Activate() {
        $this._assertState([KeyState]::Generated)
        $this.State       = [KeyState]::Active
        $this.ActivatedAt = [datetime]::UtcNow
        $this._log('Activated')
    }

    [void] Rotate([CryptoKeyLifecycle]$successor) {
        $this._assertState([KeyState]::Active)
        if ($successor.State -ne [KeyState]::Generated) {
            throw [System.InvalidOperationException]'Successor must be in Generated state'
        }
        $this.State     = [KeyState]::Rotated
        $this.RotatedAt = [datetime]::UtcNow
        $successor.Activate()
        $this._log("Rotated -> successor $($successor.KeyId)")
    }

    [void] Suspend() {
        $this._assertState([KeyState]::Active)
        $this.State = [KeyState]::Suspended
        $this._log('Suspended')
    }

    [void] Resume() {
        $this._assertState([KeyState]::Suspended)
        $this.State = [KeyState]::Active
        $this._log('Resumed')
    }

    [void] Revoke([string]$reason) {
        if ($this.State -notin @([KeyState]::Active, [KeyState]::Suspended, [KeyState]::Rotated)) {
            throw [System.InvalidOperationException]"Cannot revoke key in state $($this.State)"
        }
        $this.State     = [KeyState]::Revoked
        $this.RevokedAt = [datetime]::UtcNow
        $this._log("Revoked: $reason")
    }

    [void] Destroy() {
        $this._assertState([KeyState]::Revoked)
        [System.Array]::Clear($this._material, 0, $this._material.Length)
        $this._material = [byte[]]::new(0)
        $this.State     = [KeyState]::Destroyed
        $this._log('Destroyed -- key material zeroed')
    }

    [byte[]] GetMaterial() {
        if ($this.State -ne [KeyState]::Active) {
            throw [System.InvalidOperationException]"Key not usable in state $($this.State)"
        }
        return $this._material
    }

    hidden [void] _assertState([KeyState]$required) {
        if ($this.State -ne $required) {
            throw [System.InvalidOperationException]"Expected $required, got $($this.State)"
        }
    }

    hidden [void] _log([string]$msg) {
        $this._history.Add("$(Get-Date -Format u) | $($this.State) | $msg")
    }

    [string[]] GetHistory() { return $this._history.ToArray() }
}
