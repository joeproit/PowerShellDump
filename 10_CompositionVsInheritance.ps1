<#
.SYNOPSIS
    OOP Reference: Composition vs Inheritance
.DESCRIPTION
    Topic:        Prefer composition (has-a) over inheritance (is-a)
    Category:     Structural
    Agent Task:   Add a LoggingSecureChannel that wraps SecureChannel and logs
                  Send/Receive calls. Use composition, not inheritance.
                  Add Pester tests that swap the cipher implementation and verify
                  SecureChannel still works without modification.
    Done Conditions:
      - SecureChannel has no direct reference to FipsAesCipher
      - Swapping cipher at construction produces correct behavior
      - Pester tests pass: Invoke-Pester -Output Detailed
    Non-Scope:
      - Do not add network transport
#>

# Interfaces (reuse from 06_AbstractFactory if dot-sourced, or redefine here for standalone use)
class ICipher2 {
    [byte[]] Seal([byte[]]$pt) { throw [System.NotImplementedException]'Seal' }
    [byte[]] Open([byte[]]$ct) { throw [System.NotImplementedException]'Open' }
}

class ISigner2 {
    [byte[]] Sign([byte[]]$data)                 { throw [System.NotImplementedException]'Sign' }
    [bool]   Verify([byte[]]$data, [byte[]]$sig) { throw [System.NotImplementedException]'Verify' }
}

# Composition-based SecureChannel — injected dependencies, not inherited
class ComposedSecureChannel {
    hidden [ICipher2]$_cipher
    hidden [ISigner2]$_signer
    [string]$PeerId

    ComposedSecureChannel([ICipher2]$cipher, [ISigner2]$signer, [string]$peerId) {
        $this._cipher = $cipher
        $this._signer = $signer
        $this.PeerId  = $peerId
    }

    [hashtable] Send([byte[]]$message) {
        $sealed = $this._cipher.Seal($message)
        $sig    = $this._signer.Sign($sealed)
        return @{ Sealed=$sealed; Signature=$sig; Peer=$this.PeerId }
    }

    [byte[]] Receive([hashtable]$packet) {
        if (-not $this._signer.Verify($packet.Sealed, $packet.Signature)) {
            throw [System.Security.SecurityException]'Signature verification failed'
        }
        return $this._cipher.Open($packet.Sealed)
    }
}
