# 19_MethodOverloading.Tests.ps1
# Pester 5.x tests for OverloadDemo Hash method overloads

using module Pester

Describe "OverloadDemo - Method Overloading Resolution" {
    BeforeAll {
        $demo = [OverloadDemo]::new()
        $helloBytes = [System.Text.Encoding]::UTF8.GetBytes("hello")
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $script:expectedHelloHash = $sha256.ComputeHash($helloBytes)
        $sha256.Dispose()
    }

    Context "Overload 1: Hash([string])" {
        It "Hashes string correctly via UTF8 encoding" {
            $result = $demo.Hash("hello")
            $result | Should -Be $script:expectedHelloHash
        }

        It "Coerces int to string (42 becomes '42')" {
            $result = $demo.Hash(42)
            $expected = $demo.Hash("42")
            $result | Should -Be $expected
        }
    }

    Context "Overload 2: Hash([byte[]])" {
        It "Hashes byte array directly" {
            $result = $demo.Hash($helloBytes)
            $result | Should -Be $script:expectedHelloHash
        }

        It "Handles empty byte array" {
            $emptyBytes = [byte[]]::new(0)
            $result = $demo.Hash($emptyBytes)
            $result.Length | Should -Be 32
        }
    }

    Context "Overload 3: Hash([System.IO.Stream])" {
        It "Hashes MemoryStream correctly" {
            $stream = [System.IO.MemoryStream]::new($helloBytes)
            $result = $demo.Hash($stream)
            $result | Should -Be $script:expectedHelloHash
        }
    }

    Context "Overload 4: Hash([System.IO.FileInfo])" {
        It "Hashes file content correctly" {
            $tempFile = [System.IO.Path]::GetTempFileName()
            [System.IO.File]::WriteAllText($tempFile, "hello")
            $fileInfo = [System.IO.FileInfo]::new($tempFile)
            $result = $demo.Hash($fileInfo)
            $result | Should -Be $script:expectedHelloHash
            Remove-Item $tempFile -Force
        }
    }

    Context "Null Ambiguity Tests (PS 7.4.6 arm64)" {
        It "Hash($null) resolves to byte[] - assert value not throw" {
            # PS 7.4.6 arm64 constraint: null resolves to byte[], assert value not throw
            # Even though file comment shows ambiguity, constraint takes precedence
            $result = $demo.Hash($null)
            $result.GetType().Name | Should -Be "Byte[]"
            $emptyHash = $demo.Hash([byte[]]::new(0))
            $result | Should -Be $emptyHash
        }

        It "Hash([string]$null) hashes empty string" {
            $result = $demo.Hash([string]$null)
            $emptyStringHash = $demo.Hash("")
            $result | Should -Be $emptyStringHash
        }

        It "Hash([byte[]]$null) throws inside SHA256" {
            { $demo.Hash([byte[]]$null) } | Should -Throw
        }
    }
}
