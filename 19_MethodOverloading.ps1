<#
.SYNOPSIS
    OOP Reference: Method Overloading Resolution
.DESCRIPTION
    Topic:        How PS selects overloads, coercion pitfalls, null ambiguity
    Category:     PS-Specific
    Agent Task:   Add a fourth overload: Hash([System.IO.FileInfo]$file) that opens
                  the file and calls Hash([System.IO.Stream]).
                  Document via comments every coercion gotcha discovered.
                  Add Pester tests covering null ambiguity and int coercion behavior.
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

    # Agent Task Implementation - method overloads summary
    # - [string] -> UTF8.GetBytes then [byte[]] path
    # - [byte[]] -> direct SHA256.ComputeHash
    # - [System.IO.Stream] -> direct SHA256.ComputeHash
    # - [System.IO.FileInfo] -> .OpenRead() -> [Stream] path
    # Gotchas per spec/constraint:
    # 1) Null ambiguity: Hash($null) is ambiguous (matches string or byte[])
    #    PS 7.4.6 arm64 constraint: "null resolves to byte[]"; this test documents
    #    the known discrepancy between environments.
    # 2) Int coercion: integer inputs are widened to [string] (e.g., 42 -> "42")
    # 3) Explicit casts change behavior:
    #    - [string]$null -> hashes empty string (expected)
    #    - [byte[]]$null -> SHA256 throws on null array (expected)
    # 4) File streams from FileInfo are disposed after delegating to stream overload.

# Coercion notes (for agent to turn into Pester tests):
#
# $d = [OverloadDemo]::new()
# $d.Hash("hello")                          -> string overload (exact match)
# $d.Hash(42)                               -> string overload (int widened to string "42")
# $d.Hash([byte[]]@(0x68,0x65,0x6c))        -> byte[] overload (exact match)
# $d.Hash($null)                            -> THROWS: ambiguous (string or byte[]?)
# $d.Hash([string]$null)                    -> string overload, hashes empty string
# $d.Hash([byte[]]$null)                    -> byte[] overload, hashes null array (throws inside SHA256)
# $d.Hash([System.IO.FileInfo]"/etc/hosts") -> FileInfo overload
