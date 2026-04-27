<#
.SYNOPSIS
    OOP Reference: Method Overloading Resolution
.DESCRIPTION
    Topic:        How PS selects overloads, coercion pitfalls, null ambiguity
    Category:     PS-Specific
    Done Conditions:
      - All four overloads work correctly
      - Null-ambiguity test is explicitly documented and tested
      - Pester tests pass: Invoke-Pester -Output Detailed
    Non-Scope:
      - No generic method overloads (PS does not support them)
#>

class OverloadDemo {
    # Overload 1: string -> UTF8 encode then hash
    [byte[]] Hash([string]$data) {
        return $this.Hash([System.Text.Encoding]::UTF8.GetBytes($data))
    }

    # Overload 2: byte[] -> hash directly
    [byte[]] Hash([byte[]]$data) {
        $h = [System.Security.Cryptography.SHA256]::Create()
        try { return $h.ComputeHash($data) } finally { $h.Dispose() }
    }

    # Overload 3: stream -> hash stream
    [byte[]] Hash([System.IO.Stream]$stream) {
        $h = [System.Security.Cryptography.SHA256]::Create()
        try { return $h.ComputeHash($stream) } finally { $h.Dispose() }
    }

    # Overload 4: FileInfo -> open and delegate to stream overload
    [byte[]] Hash([System.IO.FileInfo]$file) {
        $stream = $file.OpenRead()
        try { return $this.Hash($stream) } finally { $stream.Dispose() }
    }
}

# Coercion notes:
# $d.Hash("hello")                          -> string overload
# $d.Hash(42)                               -> string overload (int coerced to "42")
# $d.Hash([byte[]]@(0x68,0x65,0x6c))        -> byte[] overload
# $d.Hash([string]$null)                    -> string overload
# $d.Hash([byte[]]$null)                    -> byte[] overload
# $d.Hash([System.IO.FileInfo]"/etc/hosts") -> FileInfo overload
