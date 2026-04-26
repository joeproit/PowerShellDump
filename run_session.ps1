param(
    [Parameter(Mandatory)]
    [string]$File
)

$basename = [System.IO.Path]::GetFileNameWithoutExtension($File)

$prompt = @"
You are working on the PowerShell OOP Crypto reference library in this repo.
Your job for this session is ONE file only. Then STOP.

## Your file:
$File

## Steps:
1. Read $File completely -- the header has your full spec.
2. Add the Agent Task implementation below the existing classes in the file.
3. Create ${basename}.Tests.ps1 with Pester 5.x tests.
4. Run: Invoke-Pester -Path ./${basename}.Tests.ps1 -Output Detailed
5. Fix failures. Log decisions in DECISIONS.md.
6. Commit: feat: $File -- [description]
7. STOP.

## Constraints:
- PS 7.4+ only. No external modules.
- Pester 5.x syntax only.
- Windows-only features: wrap with if (IsWindows) { ... }
- null resolves to byte[] in PS 7.4.6 arm64 -- assert resolved value, don't expect throw.
- Blocker: write BLOCKED in DECISIONS.md and stop.
"@

Write-Output $prompt
