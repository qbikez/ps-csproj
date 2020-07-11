BeforeAll {
    . "$psscriptroot\..\includes.ps1"

    import-module pester
    import-module csproj
    import-module publishmap
    import-module pathutils
}

Describe "fix api" {
    It "should deprecate test-slndependencies" {
        
    }
    It "should fix sln and csproj with one command" {
        
    }
}

Describe "fix csproj" {
    It "should list csproj references" {
        
    }
    It "should fix nuget paths" {
        
    }
    It "should fix csproj paths" {
        
    }
    It "should list nuget references that are not in packages.config" {
        
    }
    It "should list nuget versions mismatch between csproj and packages.config" {
        
    }
    It "should list nuget version mismatch between reference Include and HintPath" {
        
    }
}
Describe "fix solution" {
    It "should fix missing csprojs in sln" {
        # also -unique
    }
    It "should fix missing csproj refrences in csprojs" {
        # also -unique
    }
    It "should fix missing nuget references in csprojs" {
        # also -unique
    }
    It "Should remove unreferenced csprojs from sln" {
        # also -unique
    }
    It "Should list missing csproj references in sln" {
        # also -unique
    }
    It "should list missing csprojs in sln" {
        # also -unique
    }
    It "should list missing nuget references in sln" {
        # also -unique
    }
}

Describe "verify solution project set" {
    $targetdir = "TestDrive:/"
    copy-item "$inputdir/test" $targetdir -Recurse
    $slnfile = "$targetdir/test/sln/Sample.Solution/Sample.Solution.sln"
    
    It "Should return a tree of all projects and their dependencies" {
        $sln = import-sln $slnfile
        $deps = get-slndependencies $sln
        $deps | Should Not BeNullOrEmpty
        $deps.Length | Should Be 4
        $deps | format-table | out-string | write-host 
       @($deps | ? { $_.reftype -eq "nuget" }).Length | Should Be 1
       @($deps | ? { $_.reftype -eq "project" }).Length | Should Be 1
       @($deps | ? { $_.reftype -eq $null }).Length | Should Be 2 
    }
    
    $slnfile = "$inputdir/test/sln/Sample.Solution.Bad/Sample.Solution.Bad.sln"    
    It "Should report missing projects" {
        $sln = import-sln $slnfile
        $valid,$missing = test-slndependencies $sln
        $valid | Should Be $false
        $missing | Should Not BeNullOrEmpty
        $missing.Length | Should Be 2
    }
 }


Describe "fix a project with missing references" {
    $targetdir = "TestDrive:/"
    copy-item "$inputdir/test" $targetdir -Recurse
    copy-item "$inputdir/packages" "$targetdir/test" -Recurse
    copy-item "$inputdir/packages-repo" "$targetdir" -Recurse
    move-item "$targetdir/test/src/Core" "$targetdir/test/src/Core2" 
    #move-item "$targetdir/test/src" "$targetdir/test/src2" 
    
    $slnfile = "$targetdir/test/sln/Sample.Solution/Sample.Solution.sln"    
    $csproj = "$targetdir/test/src/Console/Console1/Console1.csproj"
    $packagesDir = "$targetdir/test/packages"
    $packagesRepo = "$targetdir/packages-repo"

    It "should detect missing references" {
        $deps = get-csprojdependencies $csproj
        $missing = @($deps | ? { $_.ref.isvalid -eq $false })
        $missing.length | Should Be 1
    }
    It "should fix references paths" {        
        fixcsproj $csproj -reporoot "$targetdir/test"
    
        $deps = get-csprojdependencies $csproj
        $missing = @($deps | ? { $_.ref.isvalid -eq $false })
        $missing.length | Should Be 0
       
    }
}


Describe "fix a solution with missing references" {
    $targetdir = "TestDrive:/"
    copy-item "$inputdir/test" $targetdir -Recurse
    copy-item "$inputdir/packages" "$targetdir/test" -Recurse
    copy-item "$inputdir/packages-repo" "$targetdir" -Recurse
    move-item "$targetdir/test/src/Core" "$targetdir/test/src/Core2" 
    move-item "$targetdir/test/src" "$targetdir/test/src2" 
    
    $slnfile = "$targetdir/test/sln/Sample.Solution/Sample.Solution.sln"    
   
    $packagesDir = "$targetdir/test/packages"
    $packagesRepo = "$targetdir/packages-repo"
    Context "when initializing" {
        It "Should scan repo root for csproj files" {
            $csprojs = get-childitem "$targetdir/test" -Filter "*.csproj" -Recurse
            $csprojs | Should Not BeNullOrEmpty    
        }      
        It "Should scan packages dir for nuget packages" {
            $nugets = get-installedNugets $packagesDir
            $nugets | Should Not BeNullOrEmpty
        }
        It "Should scan chosen packages source for nuget packages"{
            $list = get-availablenugets (gi $packagesRepo).FullName
            $list | Should Not BeNullOrEmpty
        }
    }
    Context "When a matching csproj can be found in repo directory" {
        It "Should replace reference path with a valid csproj" {
            $sln = import-sln $slnfile
            $deps = get-slndependencies $sln
            $valid,$missing = test-slndependencies $sln
            $valid | Should Be $false
            $missing.length | Should Be 3
            foreach($m in $missing) {
                $m.In | Should Be $sln.Fullname
            }
            fixsln $slnfile -reporoot "$targetdir/test" 
            
            $deps = get-slndependencies $slnfile
            $valid,$missing = test-slndependencies $slnfile
                
            $valid | Should Be $true         
        }
    }
    Context "When a matching nuget can be found in one of the sources" {
        It "Should repace reference with a valid nuget" {
            Set-TestInconclusive
        }
    }
}