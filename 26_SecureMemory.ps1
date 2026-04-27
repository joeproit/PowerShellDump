<#
.SYNOPSIS
    OOP Reference: Secure Memory — Pinned Buffers and DPAPI
.DESCRIPTION
    Topic:        Prevent GC from moving key material; zero on release
    Category:     Advanced Crypto
    Agent Task:   Add a static PinnedKeyBuffer.FromPassword([string]$password, [byte[]]$salt)
                  that derives a 32-byte key via PBKDF2 into a pinned buffer.
                  Add Pester tests verifying Dispose() zeroes the buffer.
    Done Conditions:
      - After Dispose(), ReadBytes() throws ObjectDisposedException
      - Buffer is zeroed (all bytes == 0) after Dispose()
      - Pester tests pass: Invoke-Pester -Output Detailed
    Non-Scope:
      - DPAPI section is Windows-only — wrap in $IsWindows guard in tests
#>

class PinnedKeyBuffer : System.IDisposable {
    hidden [byte[]]$_buffer
    hidden [System.Runtime.InteropServices.GCHandle]$_handle
    hidden [System.IntPtr]$_ptr
    hidden [bool]$_disposed

    PinnedKeyBuffer([int]$size) {
        $this._buffer  = [byte[]]::new($size)
        $this._handle  = [System.Runtime.InteropServices.GCHandle]::Alloc(
            $this._buffer,
            [System.Runtime.InteropServices.GCHandleType]::Pinned)
        $this._ptr     = $this._handle.AddrOfPinnedObject()
        $this._disposed = $false
    }

    static [PinnedKeyBuffer] Generate([int]$bytes) {
        $buf = [PinnedKeyBuffer]::new($bytes)
        [System.Security.Cryptography.RandomNumberGenerator]::Fill($buf._buffer)
        return $buf
    }

    static [PinnedKeyBuffer] FromPassword([string]$password, [byte[]]$salt) {
        $buf = [PinnedKeyBuffer]::new(32)
        $derived = [System.Security.Cryptography.Rfc2898DeriveBytes]::Pbkdf2(
            $password,
            $salt,
            100000,
            [System.Security.Cryptography.HashAlgorithmName]::SHA256,
            32)

        [System.Buffer]::BlockCopy($derived, 0, $buf._buffer, 0, $buf._buffer.Length)
        [System.Array]::Clear($derived, 0, $derived.Length)

        return $buf
    }

    [byte[]] ReadBytes() {
        if ($this._disposed) { throw [System.ObjectDisposedException]'PinnedKeyBuffer' }
        $copy = [byte[]]::new($this._buffer.Length)
        [System.Buffer]::BlockCopy($this._buffer, 0, $copy, 0, $copy.Length)
        return $copy
    }

    [bool] IsZeroed() {
        foreach ($b in $this._buffer) { if ($b -ne 0) { return $false } }
        return $true
    }

    [void] Dispose() {
        if (-not $this._disposed) {
            [System.Array]::Clear($this._buffer, 0, $this._buffer.Length)
            $this._handle.Free()
            $this._disposed = $true
        }
    }
}

# DPAPI vault (Windows only)
class DpapiKeyVault {
    [byte[]] Protect([byte[]]$secret) {
        if (-not [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)) { throw [System.PlatformNotSupportedException]'DPAPI is Windows only' }
        return [System.Security.Cryptography.ProtectedData]::Protect(
            $secret, $null,
            [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
    }

    [byte[]] Unprotect([byte[]]$blob) {
        if (-not [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)) { throw [System.PlatformNotSupportedException]'DPAPI is Windows only' }
        return [System.Security.Cryptography.ProtectedData]::Unprotect(
            $blob, $null,
            [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
    }
}
