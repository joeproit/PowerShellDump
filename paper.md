# Cryptographic Programming and Advanced OOP Patterns in PowerShell 7

*cyguin LLC — cyguin.com*

## Why this exists

PowerShell has a cryptography problem. Not a capability problem. `System.Security.Cryptography` is right there, fully accessible, and covers everything from AES-GCM to X.509 chain validation. The problem is that nobody has written seriously about how to use it well.

What exists is a pile of StackOverflow answers that copy-paste `ConvertTo-SecureString`, a handful of blog posts that stop at AES-CBC without mentioning authentication, and module documentation that treats encryption as a parameter you pass to a cmdlet. None of it covers key rotation. None of it talks about why CBC mode without a MAC is broken. Nobody has written about pinned memory, replay prevention, or algorithm agility in a PowerShell context. The production concerns that matter in real systems are simply absent from the PS ecosystem.

This paper covers cryptographic programming in PowerShell 7.x at the level a systems engineer actually needs. Not "here is how to encrypt a string" but how to build a crypto service layer that holds up under operational reality: keys that rotate, algorithms that get deprecated, messages that get replayed, memory that gets paged.

The companion repository at github.com/cyguin/PSCryptoPatterns contains 27 reference implementations and 581 Pester tests covering everything discussed here. The code is the primary artifact. This paper is the explanation.

---

## The OOP foundation

PowerShell classes compile to real .NET types at parse time. Not at runtime, not lazily on first use. At parse time. This has one consequence that bites everyone eventually: a class cannot reference a type defined below it in the same file. The parser has not seen it yet. The fix is dependency order in your dot-source sequence, which is exactly what the module loader in PSCryptoPatterns enforces.

What you get from a PS class is a genuine CLR type. `[OverloadDemo]` is not a hashtable with methods bolted on. It participates in .NET's type system, inherits from `System.Object`, and can implement real interfaces like `IDisposable` and `IComparable`. This matters because it means you can pass PS class instances to .NET APIs that expect typed parameters, and the method resolution is done by the CLR, not by PowerShell's interpreter.

Method resolution is where PS diverges from what C# developers expect. The CLR picks overloads using its standard algorithm: exact type match wins, then widening conversion. PowerShell adds aggressive coercion on top of that. Pass an `int` to a method that has a `[string]` overload and no `[int]` overload, and PS will coerce the int to a string and call the string overload. Silently. Pass `$null` to a method with both `[string]` and `[byte[]]` overloads and PS throws an ambiguity exception. Add a third overload for `[System.IO.FileInfo]` and `$null` becomes ambiguous across three types and still throws. The behavior is deterministic once you know the rules, but the rules are not obvious and the error messages do not explain them.

The `hidden` keyword is the other thing people misread. Hidden members do not appear in tab completion and do not show up in `Get-Member` output. They are not private. Any code outside the class can access them directly by name. Reflection accesses them without restriction. If you need actual encapsulation, the only option in pure PowerShell is the closure pattern: a function that returns a `PSCustomObject` whose methods close over variables in the function scope. Those variables are genuinely inaccessible from outside. The tradeoff is that you lose the type system benefits. Pick based on what you actually need.

Static constructors run exactly once, the first time any member of the type is accessed. They take no parameters. Use them for expensive one-time initialization: algorithm registries, lookup tables, pre-warmed state. The `static [ClassName]()` syntax is the only supported form. There is no way to re-run a static constructor without reloading the type, which in practice means starting a new runspace.

Without `[void]`, every value that passes through the pipeline inside a method leaks into the return value. A method that calls `Write-Host` and declares no return type will return the output of `Write-Host` to the caller. This breaks tests in non-obvious ways and causes methods that are supposed to be side-effect-only to return unexpected objects. Declare `[void]` on every method that does not intentionally return a value.

---

## Symmetric encryption done right

AES-GCM is the correct default. Not AES-CBC, not AES-CBC plus a separate HMAC bolted on afterward, not anything older. AES-GCM is an AEAD mode: it encrypts and authenticates in a single pass. The authentication tag is not separable from the decryption operation. If the ciphertext or the tag has been tampered with, decryption fails before you see any plaintext. That property is not optional in production systems.

CBC without authentication is broken in practice. The padding oracle attack has been demonstrated against real systems repeatedly. The fix is not to add HMAC after the fact in application code. The fix is to use a mode that makes authentication structurally impossible to omit. GCM does that.

The operational rules for AES-GCM are simple. The key is 16, 24, or 32 bytes. Use 32. The nonce is 12 bytes. Generate it fresh from `RandomNumberGenerator.Fill()` for every encryption operation. Never reuse a nonce under the same key. Nonce reuse under GCM is catastrophic: it leaks the authentication key and allows plaintext recovery. The tag is 16 bytes. Prepend the nonce and tag to the ciphertext for transport so the receiver has everything needed to decrypt in a single blob.

```powershell
$gcm   = [System.Security.Cryptography.AesGcm]::new($key)
$nonce = [byte[]]::new(12)
$ct    = [byte[]]::new($plaintext.Length)
$tag   = [byte[]]::new(16)
[System.Security.Cryptography.RandomNumberGenerator]::Fill($nonce)
$gcm.Encrypt($nonce, $plaintext, $ct, $tag)
return $nonce + $tag + $ct
```

For large files, `TransformFinalBlock` loads the entire payload into memory. Use `CryptoStream` instead. Write the nonce as the first 12 bytes of the output file, then pipe the input stream through a `CryptoStream`. GCM is not directly streamable via `CryptoStream` in .NET because GCM requires the full ciphertext to verify the tag before releasing plaintext. For streaming workloads above a few hundred megabytes, segment the file and encrypt each segment independently with its own nonce, or accept that you verify after the full stream is received.

One thing that surprises people: AES-GCM in .NET does not accept a null plaintext array. Zero-length plaintext is valid. Null is not. Guard against it.

---

## Asymmetric and hybrid encryption

RSA does not encrypt arbitrary data. It encrypts small payloads, typically 32 bytes or less in practice, using the recipient's public key. The correct padding is OAEP with SHA-256. PKCS1v1.5 padding is broken and has been for years. Do not use it.

```powershell
$rsa = [System.Security.Cryptography.RSA]::Create(2048)
$encrypted = $rsa.Encrypt($data, [System.Security.Cryptography.RSAEncryptionPadding]::OaepSHA256)
```

2048-bit keys are the current floor. NIST recommends 3072 for systems with lifetimes extending past 2030. Key generation is expensive, 50ms or more per key at 2048 bits. If you are generating keys in a hot path, pool them.

Hybrid encryption is the correct pattern for anything larger than a few dozen bytes. Generate an ephemeral AES-256 key, encrypt the payload with AES-GCM, encrypt the AES key with the recipient's RSA public key, transmit both. The receiver decrypts the AES key with their private key, then decrypts the payload. RSA touches 32 bytes. AES-GCM touches the payload at hardware-accelerated speeds. This is not a compromise. It is the optimal design. TLS does the same thing on every connection.

```powershell
$aesKey = [byte[]]::new(32)
[System.Security.Cryptography.RandomNumberGenerator]::Fill($aesKey)
$encryptedKey = $rsa.Encrypt($aesKey, [System.Security.Cryptography.RSAEncryptionPadding]::OaepSHA256)
```

For digital signatures use RSA-PSS, not PKCS1v1.5. PSS is probabilistic and provably secure. PKCS1v1.5 signatures are deterministic and have known structural weaknesses.

```powershell
$sig = $rsa.SignData(
    $data,
    [System.Security.Cryptography.HashAlgorithmName]::SHA256,
    [System.Security.Cryptography.RSASignaturePadding]::Pss
)
```

Verify before you trust. Signature verification is cheap. Always verify on the receiving end before acting on the payload contents.

RSA private keys are sensitive material. Export them only when necessary, encrypt the export immediately, and zero the byte array after use. `Array.Clear()` before dereferencing is the minimum. Pinned memory is better, covered in the next section.

---

## Production operational concerns

Key rotation is not a deployment event. It is a continuous operational process. The pattern that works: each encrypted record stores the ID of the key that encrypted it. The key manager retains a window of N keys, current plus N-1 predecessors. New encryptions always use the current key. Decryption accepts any key in the retention window. Rotation generates a new current key and drops the oldest if the window is full. Records encrypted with the dropped key are inaccessible. Size your window to your re-encryption cadence.

```powershell
$pkg = $mgr.Encrypt($plaintext)   # uses current key, stores key ID in package
$mgr.Rotate()                      # new current key, oldest dropped if window full
$plain = $mgr.Decrypt($pkg.KeyId, $pkg.Ciphertext)  # works if key still retained
```

Algorithm agility means your call sites never hardcode a primitive. The cipher, hash, KDF, and iteration count live in a profile object. When SHA-256 gets deprecated or NIST raises the PBKDF2 floor, you change the profile, not the code. Every package stores its profile version so decryption can route to the correct primitive regardless of what the current profile says.

Replay prevention requires a nonce registry with a TTL window. Every sealed message carries a nonce. On receipt, check the nonce against a `HashSet` of seen values. If it is present, reject. If not, record it with a timestamp and admit the message. Evict entries older than your window on each check. The window needs to be wider than your maximum expected clock skew plus network latency. 300 seconds is a reasonable default for most internal systems.

Pinned memory matters when key material lives long enough that the GC might move it or the OS might page it. `GCHandle.Alloc` with `GCHandleType.Pinned` prevents the GC from relocating the buffer. `Array.Clear` before releasing the handle zeros it.

```powershell
$handle = [System.Runtime.InteropServices.GCHandle]::Alloc(
    $buffer,
    [System.Runtime.InteropServices.GCHandleType]::Pinned)
try { # use buffer } finally {
    [System.Array]::Clear($buffer, 0, $buffer.Length)
    $handle.Free()
}
```

DPAPI is Windows-only. `ProtectedData.Protect` with `CurrentUser` scope ties the encrypted blob to the current user's credentials on the current machine. It is appropriate for secrets that need to survive process restarts but not machine migrations. Do not use it for anything you need to decrypt on a different machine or as a different user.

---

## Design patterns applied

The factory pattern solves one problem: your call sites should not import concrete types. If every consumer constructs `[AesCryptoAlgorithm]` directly, swapping the implementation requires touching every call site. A factory centralizes that decision. Pass a string, get back whatever the factory decides is correct for that algorithm name. The caller works against the base type.

The builder pattern solves configuration sprawl. A crypto service has a key size, a KDF, an iteration count, an audit flag, a rate limit. A constructor that takes all of those is unusable. A fluent builder makes each option explicit, validates at `Build()` time, and fails loudly before any key material is generated.

```powershell
$config = [CryptoConfigBuilder]::new()
    .UseAesGcm(256)
    .WithPbkdf2(200000)
    .WithAudit()
    .Build()
```

The state machine pattern is the right model for key lifecycle. A key is not just bytes. It has a lifecycle: Generated, Active, Rotated, Revoked, Destroyed. Operations that are illegal in a given state should throw immediately, not silently succeed and corrupt downstream state. Encode the transitions explicitly. `Activate()` from anything other than Generated throws. `Destroy()` from anything other than Revoked throws. The state machine makes illegal states unrepresentable at the method level.

Object pooling matters specifically for RSA. Key generation at 2048 bits costs 50ms or more. In a signing service handling volume, that cost compounds fast. Pre-warm a pool of RSA instances at startup. Rent on demand, return after use, always in a try/finally block. The pool absorbs the generation cost at startup and amortizes it across the lifetime of the process.

The decorator pattern keeps cross-cutting concerns out of the core implementation. Rate limiting, audit logging, and timing instrumentation do not belong in the cipher class. Wrap the cipher in a decorator that adds the behavior. The core class stays clean. The decorator is composable. Stack decorators if you need both rate limiting and auditing.

None of these patterns are academic. Each one appears in the companion repository applied to a real crypto service class with Pester coverage. The patterns are not the point. The problems they solve are.

---

## Testing cryptographic code

Pester 5.x syntax only. The `BeforeAll` block dot-sources the source file. Every test file is independent. No shared state between files, no module-level imports that bleed across contexts.

Crypto tests have three categories: functional correctness, failure modes, and platform guards.

Functional correctness is straightforward. Encrypt, decrypt, assert round-trip. Sign, verify, assert true. Tamper with the ciphertext, assert decryption throws. The tricky part is not writing tests that pass trivially. Asserting that `$result -ne $null` is not a test. Assert the length, assert the first N bytes match the expected nonce structure, assert that two encryptions of the same plaintext produce different ciphertext because the nonce is random.

Failure modes are where most test suites are thin. Test that a disposed object throws `ObjectDisposedException`. Test that an invalid key size throws before any key material is generated. Test that replay prevention rejects the second use of a nonce and accepts the first. Test that a tampered tag causes GCM decryption to throw, not to return garbage plaintext silently.

Do not write timing assertions like `$elapsed -lt 100`. Hardware varies, CI runners vary, load varies. The only timing assertion worth writing is that elapsed time is greater than zero, which confirms the operation actually ran.

Platform guards matter for Windows-only APIs. DPAPI and `New-SelfSignedCertificate` are the two that appear in this library. Wrap them:

```powershell
It "protects and unprotects via DPAPI" {
    if (-not $IsWindows) {
        Set-ItResult -Skipped -Because "DPAPI is Windows only"
        return
    }
    # test body
}
```

The null ambiguity behavior documented in the OOP foundation section surfaces in tests. On macOS arm64 with PS 7.4.6, `$null` passed to a method with two overloads resolved to `byte[]` and returned a value. Adding a third overload made it genuinely ambiguous and threw. Both behaviors are correct per the CLR spec. Document which behavior your tests assert and why. Future PS versions may change coercion behavior.

Constant-time comparison is not testable in Pester in any meaningful way. Assert that `CryptographicOperations.FixedTimeEquals` is being called in the implementation. Trust that the .NET implementation is correct. Do not attempt to measure timing side channels from PowerShell.

581 tests across 27 files. `Invoke-Pester -Path './*.Tests.ps1' -Output Detailed`. All green before any commit leaves the machine.

---

*Companion repository: [github.com/cyguin/PSCryptoPatterns](https://github.com/cyguin/PSCryptoPatterns)*
*581 Pester tests. MIT license. PowerShell 7.4+.*
