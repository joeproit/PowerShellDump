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

    AccessDemo() {
        $this.ReadonlyId = [System.Guid]::NewGuid().ToString('N').Substring(0,8)
        [AccessDemo]::InstanceCount++
        [AccessDemo]::_registry[$this.ReadonlyId] = $this
    }

    static [AccessDemo] GetById([string]$id) {
        return [AccessDemo]::_registry[$id]
    }
}

# Closure-based true private — GC won't expose these variables
function New-SecureVault {
    param([string]$masterPassword)

    $private:store = @{}

    [pscustomobject]@{
        Set = { param($name, $value) $private:store[$name] = $value }.GetNewClosure()
        Get = { param($name) return $private:store[$name] }.GetNewClosure()
        Has = { param($name) return $private:store.ContainsKey($name) }.GetNewClosure()
    }
}

# Reflection example (put in Pester to demonstrate the gap):
# $obj = [AccessDemo]::new()
# $field = [AccessDemo].GetField('_hiddenProp',
#     [System.Reflection.BindingFlags]'NonPublic,Instance')
# $field.GetValue($obj)   # -> "hidden but not private"
