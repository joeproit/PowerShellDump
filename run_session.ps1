param(
    [Parameter(Mandatory)]
    [string]$File
)

$basename = [System.IO.Path]::GetFileNameWithoutExtension($File)

$prompt = @"
You are working on the PowerShell OOP Crypto reference library.
Repo: /Users/joepro/dev/cyguin/workspace/tooling/powershelldump

ONE file this session. STOP when done.

## Your file:
$File

## Steps:
1. Read $File from disk. The header has your full spec.
2. Add Agent Task implementation below existing classes in $File.
3. Create ${basename}.Tests.ps1 with Pester 5.x tests.
4. Run: Invoke-Pester -Path ./${basename}.Tests.ps1 -Output Detailed
5. Fix failures. Log decisions in DECISIONS.md.
6. Commit: feat: $File -- [description]
7. Push: git push origin main
8. STOP.

## Constraints:
- PS 7.4+ only. No external modules.
- Pester 5.x syntax only.
- Windows-only features: wrap with if (IsWindows) { ... }
- null resolves to byte[] in PS 7.4.6 arm64 -- assert value, not throw.
- Blocker: write BLOCKED in DECISIONS.md and stop.
"@

Write-Output $prompt
