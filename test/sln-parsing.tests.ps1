BeforeAll {
    . $PSScriptRoot\includes.ps1

    import-module $PSScriptRoot\..\src\csproj\csproj.psm1
    import-module $PSScriptRoot\..\scripts\lib\imports\msbuild.ps1
}

Describe "parsing sln" {
    BeforeAll {
        $targetdir = "TestDrive:"
        copy-item -Recurse "$inputdir/test" "$targetdir"
        copy-item -Recurse "$inputdir/packages-repo" "$targetdir"

        $path = $env:Path
        Add-MsbuildPath
    }
    AfterAll {
        if ($path) {
             $env:Path = $path
        }
    }
    Context "when parsing sln projects" {
        BeforeAll {
            $sln = import-sln "$inputdir\platform\sln\legimi.core\Legimi.Core.Utils\Legimi.Core.Utils.sln"
            $projects = get-slnprojects $sln
        }
        It "Should return all projects" {
            #$projects | format-table | out-string | log-info
            $projects | Should -Not -BeNullOrEmpty
        }
        It "Should contain Legimi.Core.Utils" {
            $p = $projects | ? { $_.Name -eq "Legimi.Core.Utils" }
            $p | Should -Not -BeNullOrEmpty
            $p.type | Should -Be "csproj"
        }
    }

    Context "when removing project from sln" {
        BeforeAll {
            $slnfile = "$targetdir/test/sln/Sample.Solution/Sample.Solution.sln"
            $sln = import-sln $slnfile
            $oldprojects = get-slnprojects $sln
            $toremove = "Console1"
        }
        It "Should build before" {
            In (split-path -Parent $slnfile) {
                $r = nuget restore
                if ($LASTEXITCODE -ne 0) { $r | out-string | write-host }
                $LASTEXITCODE | Should -Be 0
            
                $r = msbuild (split-path -Leaf $slnfile)
                if ($LASTEXITCODE -ne 0) { $r | out-string | write-host }
                $LASTEXITCODE | Should -Be 0
            }
        }
        It "sln Should not contain removed projects" {
            remove-slnproject $sln $toremove
            $newprojects = get-slnprojects $sln
            $newprojects.Count | Should -Be ($oldprojects.Count - 1)
        }
        
        It "Should build after removal" {
            $sln.Save()
            In (split-path -Parent $slnfile) {
                $r = msbuild (split-path -Leaf $slnfile)
                if ($LASTEXITCODE -ne 0) {
                    $r | out-string | write-host
                }
                $LASTEXITCODE | Should -Be 0
            }
        }

    }
     
    Context "When updating project in sln" {
        BeforeAll {
            $sln = import-sln "$inputdir\platform\sln\legimi.core\Legimi.Core.Utils\Legimi.Core.Utils.sln"
            $oldprojects = get-slnprojects $sln
        }
        It "sln Should contain updated projects" {
            $oldprojects[0].Name = "Something.New"
            update-slnproject $sln $oldprojects[0]
            $newprojects = get-slnprojects $sln
            $newprojects.Count | Should -Be ($oldprojects.Count)
            $newprojects[0].Name | Should -Be "Something.New"
        }        
    }
}