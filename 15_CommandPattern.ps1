<#
.SYNOPSIS
    OOP Reference: Command Pattern
.DESCRIPTION
    Topic:        Encapsulate operations as objects with Undo support
    Category:     Behavioral
    Agent Task:   Add a HashFileCommand that computes SHA-256 of a file and
                  stores the result in $this.Result. It has no meaningful Undo.
                  Add Pester tests for RunAll() triggering UndoAll() on failure.
    Done Conditions:
      - Command queue executes in order
      - On failure, UndoAll() reverses completed commands in reverse order
      - Pester tests pass: Invoke-Pester -Output Detailed
    Non-Scope:
      - No async command execution
#>

class CryptoCommand {
    [string]$Id          = [System.Guid]::NewGuid().ToString('N').Substring(0,8)
    [datetime]$CreatedAt = [datetime]::UtcNow
    [bool]$Executed      = $false
    [object]$Result      = $null

    [void] Execute()    { throw [System.NotImplementedException]'Execute' }
    [void] Undo()       { throw [System.NotImplementedException]'Undo' }
    [string] Describe() { return $this.GetType().Name }
}

class NoopCommand : CryptoCommand {
    [string]$Label
    NoopCommand([string]$label) { $this.Label = $label }
    [void] Execute() { $this.Executed = $true; $this.Result = "executed:$($this.Label)" }
    [void] Undo()    { $this.Executed = $false }
    [string] Describe() { return "Noop[$($this.Label)]" }
}

class FailingCommand : CryptoCommand {
    [string] Describe() { return 'FailingCommand' }
    [void] Execute() { throw [System.InvalidOperationException]'Intentional failure' }
    [void] Undo()    { }
}

class CryptoCommandQueue {
    hidden [System.Collections.Generic.Queue[CryptoCommand]]$_queue
    hidden [System.Collections.Generic.Stack[CryptoCommand]]$_history

    CryptoCommandQueue() {
        $this._queue   = [System.Collections.Generic.Queue[CryptoCommand]]::new()
        $this._history = [System.Collections.Generic.Stack[CryptoCommand]]::new()
    }

    [void] Enqueue([CryptoCommand]$cmd) { $this._queue.Enqueue($cmd) }

    [void] RunAll() {
        while ($this._queue.Count -gt 0) {
            $cmd = $this._queue.Dequeue()
            try {
                $cmd.Execute()
                $this._history.Push($cmd)
            } catch {
                Write-Error "Command failed: $($cmd.Describe()) -- $_"
                $this.UndoAll()
                throw
            }
        }
    }

    [void] UndoAll() {
        while ($this._history.Count -gt 0) {
            $cmd = $this._history.Pop()
            $cmd.Undo()
        }
    }

    [int] PendingCount()   { return $this._queue.Count }
    [int] CompletedCount() { return $this._history.Count }
}

# Agent Task: HashFileCommand that computes SHA-256 of a file
class HashFileCommand : CryptoCommand {
    [string]$FilePath

    HashFileCommand([string]$filePath) {
        $this.FilePath = $filePath
    }

    [void] Execute() {
        if (-not (Test-Path -Path $this.FilePath -PathType Leaf)) {
            throw [System.IO.FileNotFoundException]"File not found: $($this.FilePath)"
        }
        
        $hashAlgo = [System.Security.Cryptography.SHA256]::Create()
        try {
            $fileStream = [System.IO.File]::OpenRead($this.FilePath)
            try {
                $hashBytes = $hashAlgo.ComputeHash($fileStream)
                $this.Result = [System.BitConverter]::ToString($hashBytes).Replace('-','').ToLowerInvariant()
                $this.Executed = $true
            } finally {
                $fileStream.Dispose()
            }
        } finally {
            $hashAlgo.Dispose()
        }
    }

    [void] Undo() {
        # No meaningful undo for hashing - operation is read-only
    }

    [string] Describe() {
        return "HashFile[$($this.FilePath)]"
    }
}
