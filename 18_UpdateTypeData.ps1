<#
.SYNOPSIS
    OOP Reference: Update-TypeData
.DESCRIPTION
    Topic:        Extend existing .NET types with ScriptMethod and ScriptProperty
    Category:     PS-Specific
    Agent Task:   Add a ToBase58() ScriptMethod on byte[] that encodes using a
                  Bitcoin-style base58 alphabet (no padding, no 0/O/l/I ambiguity).
                  Add a IsKeySize ScriptProperty that returns $true if Length is 16, 24, or 32.
                  Add Pester tests for all extended methods.
    Done Conditions:
      - All new methods are idempotent (can be called multiple times)
      - -Force prevents duplicate-definition errors on reload
      - Pester tests pass: Invoke-Pester -Output Detailed
    Non-Scope:
      - Do not modify types globally without the -Force flag
#>

# Extend byte[] with crypto convenience methods
Update-TypeData -TypeName 'System.Byte[]' -MemberType ScriptMethod -MemberName 'ToHex' -Value {
    ($this | ForEach-Object { $_.ToString('x2') }) -join ''
} -Force

Update-TypeData -TypeName 'System.Byte[]' -MemberType ScriptMethod -MemberName 'ToBase64' -Value {
    [Convert]::ToBase64String($this)
} -Force

Update-TypeData -TypeName 'System.Byte[]' -MemberType ScriptMethod -MemberName 'SHA256Hash' -Value {
    $h = [System.Security.Cryptography.SHA256]::Create()
    try { return $h.ComputeHash($this) } finally { $h.Dispose() }
} -Force

Update-TypeData -TypeName 'System.Byte[]' -MemberType ScriptProperty -MemberName 'IsKeySize' -Value {
    $this.Length -in @(16, 24, 32)
} -Force

Update-TypeData -TypeName 'System.String' -MemberType ScriptMethod -MemberName 'ToUTF8Bytes' -Value {
    [System.Text.Encoding]::UTF8.GetBytes($this)
} -Force

Update-TypeData -TypeName 'System.String' -MemberType ScriptMethod -MemberName 'SHA256Hex' -Value {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($this)
    $h     = [System.Security.Cryptography.SHA256]::Create()
    try { return ($h.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '' }
    finally { $h.Dispose() }
} -Force

# Usage after loading:
# $key = [byte[]]::new(32)
# [System.Security.Cryptography.RandomNumberGenerator]::Fill($key)
# $key.ToHex()
# $key.ToBase64()
# $key.SHA256Hash().ToHex()
# $key.IsKeySize       # -> $true
# "hello world".SHA256Hex()
