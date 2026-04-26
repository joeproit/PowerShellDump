<#
.SYNOPSIS
    OOP Reference: Operator Overloading (Workaround)
.DESCRIPTION
    Topic:        PS has no custom operators — IComparable/IEquatable plus static methods
    Category:     PS-Specific
    Agent Task:   Add a static Merge([CryptoKeyPair[]]$keys) method that returns
                  the strongest non-expired key from the array.
                  Add Pester tests verifying Sort-Object, -eq, and hashtable keying.
    Done Conditions:
      - $k1 -eq $k2 works via IEquatable
      - Sort-Object uses IComparable (sorts by expiry)
      - Hashtable keys deduplicate by KeyId via GetHashCode
      - Pester tests pass: Invoke-Pester -Output Detailed
    Non-Scope:
      - No operator overloading via C# inline types
#>

class CryptoKeyPair : System.IComparable, System.IEquatable[object] {
    [string]$KeyId
    [datetime]$Expires
    [int]$Strength

    CryptoKeyPair([string]$id, [int]$strength, [int]$validDays) {
        $this.KeyId    = $id
        $this.Strength = $strength
        $this.Expires  = [datetime]::UtcNow.AddDays($validDays)
    }

    [int] CompareTo([object]$other) {
        if ($null -eq $other) { return 1 }
        return $this.Expires.CompareTo(([CryptoKeyPair]$other).Expires)
    }

    [bool] Equals([object]$other) {
        if ($null -eq $other) { return $false }
        if ($other -isnot [CryptoKeyPair]) { return $false }
        return $this.KeyId -eq ([CryptoKeyPair]$other).KeyId
    }

    [int] GetHashCode() { return $this.KeyId.GetHashCode() }

    static [bool] IsStrongerThan([CryptoKeyPair]$a, [CryptoKeyPair]$b) {
        return $a.Strength -gt $b.Strength
    }

    static [CryptoKeyPair] SelectStronger([CryptoKeyPair]$a, [CryptoKeyPair]$b) {
        return ($a.Strength -ge $b.Strength) ? $a : $b
    }

    [bool] IsExpired() { return [datetime]::UtcNow -gt $this.Expires }
}
