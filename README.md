# PSCryptoPatterns

Advanced OOP and cryptographic programming patterns for PowerShell 7.x.

27 reference implementations covering the full production crypto stack: AES-GCM, RSA, hybrid encryption, key rotation, replay prevention, pinned memory, certificate chain validation, and the OOP patterns that hold it together at scale.

581 Pester tests. All green.

## What is in here

The PS crypto ecosystem is thin. Blog posts stop at AES-CBC. Nobody covers key rotation, algorithm agility, or pinned memory in a PowerShell context. This library covers the production concerns that actually matter.

| File | Topic |
|------|-------|
| 01_ClassMechanics.ps1 | Static ctors, load order, hidden vs private, void return |
| 02_Inheritance.ps1 | Constructor chaining, method override, type checking |
| 03_InterfacePatterns.ps1 | IDisposable, IComparable, custom interface enforcement |
| 04_AccessModifiers.ps1 | hidden, static, readonly simulation, closure-based private |
| 05_FactoryMethod.ps1 | Factory method |
| 06_AbstractFactory.ps1 | Abstract factory, crypto suite families |
| 07_BuilderPattern.ps1 | Fluent construction with validation |
| 08_ObjectPool.ps1 | RSA instance pooling |
| 09_Prototype.ps1 | Deep clone |
| 10_CompositionVsInheritance.ps1 | Composition, dependency injection |
| 11_MixinScriptblock.ps1 | Scriptblock injection |
| 12_GenericCollections.ps1 | Typed Dictionary, List, Queue in classes |
| 13_TemplateMethod.ps1 | Algorithm skeleton, subclass fill |
| 14_StateMachine.ps1 | Key lifecycle state machine |
| 15_CommandPattern.ps1 | Operations as objects, undo |
| 16_NullObject.ps1 | Null object pattern |
| 17_EventsDelegates.ps1 | System.Action delegates as event hooks |
| 18_UpdateTypeData.ps1 | Extending .NET types |
| 19_MethodOverloading.ps1 | Overload resolution, coercion pitfalls |
| 20_StaticConstructors.ps1 | Type-level initialization |
| 21_OperatorOverloading.ps1 | IComparable, IEquatable |
| 22_RecursiveTypes.ps1 | Self-referential classes |
| 23_KeyRotation.ps1 | Rotating key manager with retention window |
| 24_AlgorithmAgility.ps1 | Swap primitives via config |
| 25_ReplayPrevention.ps1 | Nonce tracking with TTL window |
| 26_SecureMemory.ps1 | Pinned GC buffers, zero-on-release, DPAPI |
| 27_CertChainValidation.ps1 | X.509 chain validation, thumbprint pinning |

## Requirements

- PowerShell 7.4+
- Pester 5.x

```powershell
Install-Module Pester -Force -SkipPublisherCheck
```

## Run the tests

```powershell
Invoke-Pester -Path './*.Tests.ps1' -Output Detailed
```

## Load as a module

```powershell
Import-Module ./PSCryptoPatterns.psd1
```

## Read the paper

cyguin.com

## License

MIT. See LICENSE.
