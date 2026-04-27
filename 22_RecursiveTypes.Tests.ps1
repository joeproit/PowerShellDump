BeforeAll {
    . $PSScriptRoot/22_RecursiveTypes.ps1
}

Describe "CertificateChainNode" {
    Context "Basic Construction and Chain Methods" {
        It "Should create a single node with depth 0" {
            $node = [CertificateChainNode]::new("CN=Root", "Self-Signed")
            $node.Depth() | Should -Be 0
        }

        It "Should calculate depth correctly for 2-level chain" {
            $root = [CertificateChainNode]::new("CN=Root", "Self-Signed")
            $child = [CertificateChainNode]::new("CN=Intermediate", "CN=Root")
            $root.AddChild($child)
            
            $child.Depth() | Should -Be 1
        }

        It "Should calculate depth correctly for 3-level chain" {
            $root = [CertificateChainNode]::new("CN=Root", "Self-Signed")
            $intermediate = [CertificateChainNode]::new("CN=Intermediate", "CN=Root")
            $leaf = [CertificateChainNode]::new("CN=Leaf", "CN=Intermediate")
            
            $root.AddChild($intermediate)
            $intermediate.AddChild($leaf)
            
            $leaf.Depth() | Should -Be 2
        }

        It "Should return subjects in leaf-to-root order" {
            $root = [CertificateChainNode]::new("CN=Root", "Self-Signed")
            $intermediate = [CertificateChainNode]::new("CN=Intermediate", "CN=Root")
            $leaf = [CertificateChainNode]::new("CN=Leaf", "CN=Intermediate")
            
            $root.AddChild($intermediate)
            $intermediate.AddChild($leaf)
            
            $subjects = $leaf.GetChainSubjects()
            $subjects.Count | Should -Be 3
            $subjects[0] | Should -Be "CN=Leaf"
            $subjects[1] | Should -Be "CN=Intermediate"
            $subjects[2] | Should -Be "CN=Root"
        }
    }

    Context "BuildChain Static Factory Method" {
        It "Should throw on null subjects array" {
            { [CertificateChainNode]::BuildChain($null) } | Should -Throw
        }

        It "Should throw on empty subjects array" {
            { [CertificateChainNode]::BuildChain(@()) } | Should -Throw
        }

        It "Should create single-node chain from 1-element array" {
            $leaf = [CertificateChainNode]::BuildChain(@("CN=Root"))
            
            $leaf.Subject | Should -Be "CN=Root"
            $leaf.Issuer | Should -Be "Self-Signed"
            $leaf.Depth() | Should -Be 0
            $leaf.Parent | Should -BeNullOrEmpty
        }

        It "Should create 2-level chain from 2-element array" {
            $leaf = [CertificateChainNode]::BuildChain(@("CN=Root", "CN=Leaf"))
            
            $leaf.Subject | Should -Be "CN=Leaf"
            $leaf.Issuer | Should -Be "CN=Root"
            $leaf.Depth() | Should -Be 1
            $leaf.Parent.Subject | Should -Be "CN=Root"
        }

        It "Should create 3-level chain from 3-element array" {
            $leaf = [CertificateChainNode]::BuildChain(@("CN=Root", "CN=Intermediate", "CN=Leaf"))
            
            $leaf.Subject | Should -Be "CN=Leaf"
            $leaf.Depth() | Should -Be 2
        }

        It "Should return correct GetChainSubjects for BuildChain output (2 levels)" {
            $leaf = [CertificateChainNode]::BuildChain(@("CN=Root", "CN=Leaf"))
            
            $subjects = $leaf.GetChainSubjects()
            $subjects.Count | Should -Be 2
            $subjects[0] | Should -Be "CN=Leaf"
            $subjects[1] | Should -Be "CN=Root"
        }

        It "Should return correct GetChainSubjects for BuildChain output (3 levels)" {
            $leaf = [CertificateChainNode]::BuildChain(@("CN=Root", "CN=Intermediate", "CN=Leaf"))
            
            $subjects = $leaf.GetChainSubjects()
            $subjects.Count | Should -Be 3
            $subjects[0] | Should -Be "CN=Leaf"
            $subjects[1] | Should -Be "CN=Intermediate"
            $subjects[2] | Should -Be "CN=Root"
        }

        It "Should return correct GetChainSubjects for BuildChain output (5 levels)" {
            $leaf = [CertificateChainNode]::BuildChain(@(
                "CN=RootCA",
                "CN=IntermediateCA1",
                "CN=IntermediateCA2",
                "CN=IssuingCA",
                "CN=EndEntity"
            ))
            
            $subjects = $leaf.GetChainSubjects()
            $subjects.Count | Should -Be 5
            $subjects[0] | Should -Be "CN=EndEntity"
            $subjects[1] | Should -Be "CN=IssuingCA"
            $subjects[2] | Should -Be "CN=IntermediateCA2"
            $subjects[3] | Should -Be "CN=IntermediateCA1"
            $subjects[4] | Should -Be "CN=RootCA"
        }

        It "Should return correct Depth for BuildChain output (5 levels)" {
            $leaf = [CertificateChainNode]::BuildChain(@(
                "CN=RootCA",
                "CN=IntermediateCA1",
                "CN=IntermediateCA2",
                "CN=IssuingCA",
                "CN=EndEntity"
            ))
            
            $leaf.Depth() | Should -Be 4
        }
    }
}

Describe "KeyHistoryNode" {
    Context "Basic Construction and History" {
        It "Should create node with key material" {
            $key = [byte[]]::new(32)
            $node = [KeyHistoryNode]::new($key)
            
            $node.KeyMaterial | Should -Not -BeNullOrEmpty
            $node.KeyMaterial.Length | Should -Be 32
            $node.HistoryLength() | Should -Be 1
        }

        It "Should track history length correctly with previous node" {
            $key1 = [byte[]]::new(16)
            $key2 = [byte[]]::new(16)
            
            $old = [KeyHistoryNode]::new($key1)
            $current = [KeyHistoryNode]::new($key2)
            $current.Previous = $old
            
            $current.HistoryLength() | Should -Be 2
        }

        It "Should track history length correctly with 3-node chain" {
            $old1 = [KeyHistoryNode]::new([byte[]]::new(16))
            $old2 = [KeyHistoryNode]::new([byte[]]::new(16))
            $current = [KeyHistoryNode]::new([byte[]]::new(16))
            
            $old2.Previous = $old1
            $current.Previous = $old2
            
            $current.HistoryLength() | Should -Be 3
        }

        It "Should set ActiveFrom timestamp on creation" {
            $before = [datetime]::UtcNow
            Start-Sleep -Milliseconds 10
            $node = [KeyHistoryNode]::new([byte[]]::new(16))
            Start-Sleep -Milliseconds 10
            $after = [datetime]::UtcNow
            
            $node.ActiveFrom | Should -BeGreaterThan $before
            $node.ActiveFrom | Should -BeLessThan $after
        }
    }
}
