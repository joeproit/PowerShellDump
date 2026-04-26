<#
.SYNOPSIS
    OOP Reference: Static Constructors / Type Initializers
.DESCRIPTION
    Topic:        One-time type-level initialization in PS classes
    Category:     PS-Specific
    Agent Task:   Add a static Refresh() method that re-runs initialization
                  (useful when new algorithms are registered at runtime).
                  Add a static GetKeySize([string]$algo) that throws on unknown.
                  Add Pester tests verifying static ctor fires exactly once.
    Done Conditions:
      - Static ctor does not fire twice on multiple accesses
      - GetKeySize throws ArgumentException on unknown algorithm
      - Pester tests pass: Invoke-Pester -Output Detailed
    Non-Scope:
      - No thread-safety needed for static ctor (PS is single-threaded per runspace)
#>

class AlgorithmCatalog {
    static [System.Collections.Generic.HashSet[string]]$Supported
    static [System.Collections.Generic.Dictionary[string,int]]$KeySizes
    static [string]$DefaultAlgorithm
    hidden static [int]$_initCount = 0

    static AlgorithmCatalog() {
        [AlgorithmCatalog]::_Initialize()
    }

    hidden static [void] _Initialize() {
        [AlgorithmCatalog]::_initCount++
        [AlgorithmCatalog]::Supported = [System.Collections.Generic.HashSet[string]]::new(
            [string[]]@('AES-128-GCM','AES-256-GCM','ChaCha20-Poly1305','AES-256-CBC'),
            [System.StringComparer]::OrdinalIgnoreCase)

        [AlgorithmCatalog]::KeySizes = [System.Collections.Generic.Dictionary[string,int]]::new(
            [System.StringComparer]::OrdinalIgnoreCase)
        [AlgorithmCatalog]::KeySizes['AES-128-GCM']       = 128
        [AlgorithmCatalog]::KeySizes['AES-256-GCM']       = 256
        [AlgorithmCatalog]::KeySizes['ChaCha20-Poly1305'] = 256
        [AlgorithmCatalog]::KeySizes['AES-256-CBC']       = 256
        [AlgorithmCatalog]::DefaultAlgorithm = 'AES-256-GCM'
    }

    static [void] Refresh() { [AlgorithmCatalog]::_Initialize() }

    static [bool] IsSupported([string]$algo) {
        return [AlgorithmCatalog]::Supported.Contains($algo)
    }

    static [int] GetKeySize([string]$algo) {
        $size = 0
        if (-not [AlgorithmCatalog]::KeySizes.TryGetValue($algo, [ref]$size)) {
            throw [System.ArgumentException]"Unknown algorithm: $algo"
        }
        return $size
    }

    static [int] GetInitCount() { return [AlgorithmCatalog]::_initCount }
}
