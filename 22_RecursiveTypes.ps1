<#
.SYNOPSIS
    OOP Reference: Recursive / Self-Referential Types
.DESCRIPTION
    Topic:        Classes that reference themselves — trees, linked lists, cert chains
    Category:     PS-Specific
    Agent Task:   Add a static BuildChain([string[]]$subjects) factory method that
                  constructs a chain from an array of subject strings (index 0 = root).
                  Add Pester tests verifying Depth() and GetChainSubjects() output.
    Done Conditions:
      - Depth() returns correct integer for N-level chain
      - GetChainSubjects() returns subjects in leaf-to-root order
      - Pester tests pass: Invoke-Pester -Output Detailed
    Non-Scope:
      - No X.509 parsing from real cert files
#>

class CertificateChainNode {
    [string]$Subject
    [string]$Issuer
    [CertificateChainNode]$Parent
    [System.Collections.Generic.List[CertificateChainNode]]$Children

    CertificateChainNode([string]$subject, [string]$issuer) {
        $this.Subject  = $subject
        $this.Issuer   = $issuer
        $this.Children = [System.Collections.Generic.List[CertificateChainNode]]::new()
    }

    [void] AddChild([CertificateChainNode]$child) {
        $child.Parent = $this
        $this.Children.Add($child)
    }

    [System.Collections.Generic.List[string]] GetChainSubjects() {
        $result = [System.Collections.Generic.List[string]]::new()
        $result.Add($this.Subject)
        if ($null -ne $this.Parent) {
            $result.AddRange($this.Parent.GetChainSubjects())
        }
        return $result
    }

    [int] Depth() {
        if ($null -eq $this.Parent) { return 0 }
        return 1 + $this.Parent.Depth()
    }
}

# Self-referential linked list for key history
class KeyHistoryNode {
    [byte[]]$KeyMaterial
    [datetime]$ActiveFrom
    [KeyHistoryNode]$Previous

    KeyHistoryNode([byte[]]$key) {
        $this.KeyMaterial = $key
        $this.ActiveFrom  = [datetime]::UtcNow
    }

    [int] HistoryLength() {
        if ($null -eq $this.Previous) { return 1 }
        return 1 + $this.Previous.HistoryLength()
    }
}
