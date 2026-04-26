# PowerShell OOP + Cryptography Reference

27 files covering advanced OOP patterns and cryptographic programming in PowerShell 7.x.

Each file is a standalone agent task. Pass one file at a time to an agent session.

---

## File Index

| File | Topic | Category |
|------|-------|----------|
| 01_ClassMechanics.ps1 | Static ctors, load order, hidden vs private, [void] return | Fundamentals |
| 02_Inheritance.ps1 | Constructor chaining, method override, type checking | Fundamentals |
| 03_InterfacePatterns.ps1 | IDisposable, IComparable, custom interface enforcement | Fundamentals |
| 04_AccessModifiers.ps1 | hidden, static, readonly simulation, closure-based private | Fundamentals |
| 05_FactoryMethod.ps1 | Factory method — decouple creation from usage | Creational |
| 06_AbstractFactory.ps1 | Abstract factory — families of related crypto objects | Creational |
| 07_BuilderPattern.ps1 | Fluent multi-step construction with validation | Creational |
| 08_ObjectPool.ps1 | Pool expensive RSA instances for reuse | Creational |
| 09_Prototype.ps1 | Deep clone without re-running expensive ctors | Creational |
| 10_CompositionVsInheritance.ps1 | has-a vs is-a, dependency injection | Structural |
| 11_MixinScriptblock.ps1 | Inject cross-cutting behavior via scriptblocks | Structural |
| 12_GenericCollections.ps1 | Strongly-typed Dictionary, List, Queue in classes | Structural |
| 13_TemplateMethod.ps1 | Base class skeleton; subclasses fill steps | Behavioral |
| 14_StateMachine.ps1 | Enum-driven key lifecycle state machine | Behavioral |
| 15_CommandPattern.ps1 | Encapsulate operations as objects with Undo | Behavioral |
| 16_NullObject.ps1 | Replace null checks with do-nothing implementations | Behavioral |
| 17_EventsDelegates.ps1 | System.Action delegates as event hooks | Behavioral |
| 18_UpdateTypeData.ps1 | Extend .NET types with ScriptMethod/ScriptProperty | PS-Specific |
| 19_MethodOverloading.ps1 | Overload resolution, coercion pitfalls, null ambiguity | PS-Specific |
| 20_StaticConstructors.ps1 | One-time type-level initialization | PS-Specific |
| 21_OperatorOverloading.ps1 | IComparable/IEquatable workaround for operators | PS-Specific |
| 22_RecursiveTypes.ps1 | Self-referential classes — trees, linked lists, chains | PS-Specific |
| 23_KeyRotation.ps1 | Rotating key manager with retention window | Advanced Crypto |
| 24_AlgorithmAgility.ps1 | Swap primitives via config without changing call sites | Advanced Crypto |
| 25_ReplayPrevention.ps1 | Nonce tracking with TTL window | Advanced Crypto |
| 26_SecureMemory.ps1 | Pinned GC buffers, zero-on-release, DPAPI vault | Advanced Crypto |
| 27_CertChainValidation.ps1 | X.509 chain validation, thumbprint pinning | Advanced Crypto |

---

## Agent Instructions (per file)

Each file header contains:
- `.SYNOPSIS` — one-line topic
- `.DESCRIPTION` with:
  - `Topic` — what this file covers
  - `Category` — which domain
  - `Agent Task` — specific extension work to do
  - `Done Conditions` — Pester tests must pass
  - `Non-Scope` — what NOT to implement

**Agent session protocol:**
1. Read the file header completely before writing any code
2. Do not modify existing class definitions — extend or add alongside them
3. Write Pester tests in a matching `*.Tests.ps1` file
4. Run `Invoke-Pester -Output Detailed` before declaring done
5. Commit with message: `feat: [filename] -- [brief description]`

---

## Requirements

- PowerShell 7.4+
- Pester 5.x (`Install-Module Pester -Force`)
- No additional modules required — all crypto uses `System.Security.Cryptography`

## Running All Tests

```powershell
Invoke-Pester -Path . -Output Detailed -Recurse
```
