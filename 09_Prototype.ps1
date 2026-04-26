<#
.SYNOPSIS
    OOP Reference: Prototype / Deep Clone Pattern
.DESCRIPTION
    Topic:        Clone objects without re-running expensive constructors
    Category:     Creational
    Agent Task:   Add a CloneWithNewKey() method that deep-clones the config and
                  generates fresh random KeyMaterial. Add Pester tests verifying
                  that mutations to the clone do not affect the original.
    Done Conditions:
      - Clone() produces independent copy (mutate clone, original unchanged)
      - CloneWith() applies overrides correctly
      - byte[] is deep-copied, not reference-copied
      - Pester tests pass: Invoke-Pester -Output Detailed
    Non-Scope:
      - No serialization-based clone (BinaryFormatter is deprecated)
#>

class CloneableConfig {
    [string]$Algorithm
    [int]$KeyBits
    [hashtable]$Parameters
    [byte[]]$KeyMaterial

    CloneableConfig([string]$algo, [int]$bits) {
        $this.Algorithm   = $algo
        $this.KeyBits     = $bits
        $this.Parameters  = @{}
        $this.KeyMaterial = [byte[]]::new(32)
        [System.Security.Cryptography.RandomNumberGenerator]::Fill($this.KeyMaterial)
    }

    [CloneableConfig] Clone() {
        $copy             = [CloneableConfig]::new($this.Algorithm, $this.KeyBits)
        foreach ($k in $this.Parameters.Keys) {
            $copy.Parameters[$k] = $this.Parameters[$k]
        }
        $copy.KeyMaterial = [byte[]]::new($this.KeyMaterial.Length)
        [System.Buffer]::BlockCopy($this.KeyMaterial, 0, $copy.KeyMaterial, 0, $this.KeyMaterial.Length)
        return $copy
    }

    [CloneableConfig] CloneWith([hashtable]$overrides) {
        $copy = $this.Clone()
        foreach ($k in $overrides.Keys) { $copy.$k = $overrides[$k] }
        return $copy
    }

    [CloneableConfig] CloneWithNewKey() {
        $copy = $this.Clone()
        # Generate fresh random KeyMaterial
        $copy.KeyMaterial = [byte[]]::new($this.KeyMaterial.Length)
        [System.Security.Cryptography.RandomNumberGenerator]::Fill($copy.KeyMaterial)
        return $copy
    }
}
