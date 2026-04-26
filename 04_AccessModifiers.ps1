<#
.SYNOPSIS
    OOP Reference: Access Modifiers
.DESCRIPTION
    Topic:        hidden, static, readonly simulation, closure-based true private
    Category:     Fundamentals
    Agent Task:   Add a registry size limit to AccessDemo. Demonstrate via Pester that
                  reflection CAN access $_hiddenProp despite hidden keyword.
                  Add a second New-SecureVault instance and verify vaults do not share state.
    Done Conditions:
      - Reflection test explicitly shows hidden != private
      - Two vault instances are independent
      - Pester tests pass: Invoke-Pester -Output Detailed
    Non-Scope:
      - No module-level scope tricks
#>

class AccessDemo {
    [string]$PublicProp = "anyone"
    hidden [string]$_hiddenProp = "hidden but not private"
    static [int]$InstanceCount = 0
    [string]$ReadonlyId
    hidden static [hashtable]$_registry = @{}
    hidden static [int]$_maxRegistrySize = 100

    AccessDemo() {
        $this.ReadonlyId = [System.Guid]::NewGuid().ToString('N').Substring(0,8)
        [AccessDemo]::InstanceCount++
        
        # Enforce registry size limit
        if ([AccessDemo]::_registry.Count -ge [AccessDemo]::_maxRegistrySize) {
            throw "Registry size limit exceeded. Maximum: $([AccessDemo]::_maxRegistrySize)"
        }
        
        [AccessDemo]::_registry[$this.ReadonlyId] = $this
    }

    static [AccessDemo] GetById([string]$id) {
        return [AccessDemo]::_registry[$id]
    }
    
    static [int] GetRegistrySize() {
        return [AccessDemo]::_registry.Count
    }
    
    static [void] ClearRegistry() {
        [AccessDemo]::_registry.Clear()
        [AccessDemo]::InstanceCount = 0
    }
    
    static [int] GetMaxRegistrySize() {
        return [AccessDemo]::_maxRegistrySize
    }
    
    static [void] SetMaxRegistrySize([int]$size) {
        if ($size -le 0) {
            throw "Max registry size must be positive"
        }
        [AccessDemo]::_maxRegistrySize = $size
    }
}

# Closure-based true private — GC won't expose these variables
function New-SecureVault {
    param([string]$masterPassword)

    $store = @{}

    [pscustomobject]@{
        Set = { param($name, $value) $store[$name] = $value }.GetNewClosure()
        Get = { param($name) return $store[$name] }.GetNewClosure()
        Has = { param($name) return $store.ContainsKey($name) }.GetNewClosure()
    }
}
