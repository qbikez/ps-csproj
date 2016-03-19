. "$PSScriptRoot\..\includes.ps1"

import-module pester
import-module csproj
import-module pathutils

Describe "Converting dll reference to project" {    

    $i = $MyInvocation 
    $targetdir = get-testoutputdir 
    copy-item "$inputdir\test" "$targetdir\test" -recurse -force
    copy-item "$inputdir\packages" "$targetdir\packages" -recurse -Force
        
    $slnfile = "$targetdir\test\sln\Sample.Solution\Sample.Solution.sln"
    $slndir = split-path -parent $slnfile
    $packagesdir = "$targetdir\test\packages"
    
    $referenceName = "Core.LibraryProject2"
    $targetProject = "$targetdir\test\src\Core\Core.Library2\Core.LibraryProject2.csproj"
    $specificProject = "Console1"
    
    $sln = import-sln $slnfile
    
    $projects = $sln | get-slnprojects | ? { $_.Type -eq "csproj" }
    $projects = $projects | ? { $_.Name -eq $specificProject }       
    
    $projects | % {
        convert-nugettoprojectreference $referencename $targetProject $_.FullName -confirm:$false
    }    
   
}

Describe "Converting Project reference to nuget" {
    
    $targetdir = get-testoutputdir 

    copy-item "$inputdir\test" "$targetdir\test" -recurse 
    #copy-item "$inputdir\packages" "$targetdir\packages" -recurse
    copy-item "$inputdir\packages-repo" "$targetdir\packages-repo" -recurse -Force

    $slnfile = "$targetdir\test\sln\Sample.Solution\Sample.Solution.sln"
    $slndir = split-path -parent $slnfile
    $packagesdir = "$targetdir\test\packages"
    if (!(test-path $packagesdir)) { $null = new-item $packagesdir -type directory }
    
    $sln = import-sln $slnfile
   
    Context "on start" { 
      
      In $slndir {
        It "Should restore on start" {
            $o = nuget restore -nocache
            if ($lastexitcode -ne 0) {
                $o | % { write-warning $_ }
            }
            $lastexitcode | Should Be 0
        }
        It "Should build on start" {
                #Add-MsbuildPath
                $msbuildout = & msbuild 2>&1
                $lec = $lastexitcode 
                if ($lec -ne 0) {
                    $msbuildout | % { Write-Warning $_ }
                }
                $lec | Should Be 0
        }
      }
    }
    
    
    Context "When loading sln file" {
        $projectName = "Core.LibraryNuget1"
    
        It "Should resolve all sln projects" {
            $sln.gettype().Name | should Be "Sln"
            $projects = $sln | get-slnprojects
            $projects | Should Not BeNullOrEmpty
            $projects | % {
                $_ | Should Not BeNullOrEmpty
                $_.path | Should Not BeNullOrEmpty
                if ($_.type -eq "csproj") {
                    $p = import-csproj (join-path $slndir $_.path)
                    $p | should not BeNullOrEmpty
                }
            }
        }
        
        It "sln should contain project $projectName" {
            $projects = $sln | get-slnprojects
            $p = $projects | ? { $_.Name -eq $projectName }
            $p | Should Not BeNullOrEmpty
            $p.path | Should be "..\..\src\Core\Core.Library1\Core.LibraryNuget1.csproj"
        }
        
        It "Should list all references to $projectname" {
            $refs = get-referencesto $sln $projectname 
            $refs | Should Not BeNullOrEmpty
        }
    }
    
    

    Context "When converting project with matching nuget" {
        
        $projectname = "Core.LibraryNuget1"
        #$null = new-item "$targetdir\packages\$projectname.1.0.1\lib\" -type directory
        #$null = new-item "$targetdir\packages\$projectname.1.0.1\lib\$projectname.dll" -type file
        
        $projects = $sln | get-slnprojects | ? { $_.type -eq "csproj" }
        $oldpkgs = $projects | % { 
            $dir = Split-Path -Parent $_.FullName
            return @{
                pkgs = get-packagesconfig "$dir/packages.config"
                project = $_
            }
         }

        $oldrefs = get-referencesto $sln $projectname
        It "should convert without errors" {
            In $slndir {
                $outdir = (get-relativepath $slndir $packagesdir)
                $o = nuget install "$projectname" -out $outdir
                $o
                $lastexitcode | should be 0
            }
            { $sln | convert-referencesToNuget -project "$projectname"  -packagesdir $packagesdir } | Should not throw
        }
        
        It "should not leave any project reference" {
            $refs = get-referencesto $sln $projectname 
            $projrefs = @($refs | ? { $_.type -eq "project" })
            if ($projrefs -ne $null -or $projrefs.Length -gt 0) {
                $projrefs | % { write-host $_ }
            } 
            $projrefs | Should BeNullOrEmpty
            
            $refs | Should Not BeNullOrEmpty
            
            $nugetrefs = $refs | ? { $_.type -eq "nuget" }  
            $nugetrefs | Should Not BeNullOrEmpty
            
            $refs.count | Should Be $oldrefs.Count
            $nugetrefs.Count | Should Be $refs.Count
        }
        
        It "converted references should exist in packages.config" {
            $refs = get-referencesto $sln $projectname 
            $nugetrefs = @($refs | ? { $_.type -eq "nuget" }) 
            foreach($n in $nugetrefs) {
                $dir = split-path $n.projectpath
                $pkg = get-packagesconfig "$dir/packages.config"
                $pkg | Should Not BeNullOrEmpty
                $pkg.packages | Should Not BeNullOrEmpty
                $pkg.packages | ? { $_.id -eq $n.ref.name } | Should Not BeNullOrEmpty
            }
        }
        
        $cases = $oldpkgs | % { @{ projectName = $_.project.Name; pkgs = $_.pkgs; project = $_.project } }
        It "should not remove previous packages from packages.config in project <projectname>" -TestCases $cases {
            param($projectname, $pkgs, $project)
            $newpkgs = get-packagesconfig $project.fullname
            $pkgs.packages.lenght -le $newpkgs.packages.length | should be $true 
        }

        It "converted references should have relative paths" {
            ipmo pathutils
            $refs = get-referencesto $sln $projectname 
            $nugetrefs = $refs | ? { $_.type -eq "nuget" }  
            foreach($n in $nugetrefs) {
                $n.ref.path | Should not benullorempty
                test-ispathrelative $n.ref.path | should be $true 
            }
        }
        
        in $slndir {
        It "Should restore after conversion" {
            remove-item "$targetdir/test/packages" -force -Recurse
            $o = nuget restore -nocache
            if ($lastexitcode -ne 0) {
                $o | % { write-warning $_ }
            }
            $lastexitcode | Should Be 0
        }
        }

        It "Should build after conversion" {
            #Add-MsbuildPath
            In $slndir {
                $msbuildout = & msbuild 2>&1
            }
            $lec = $lastexitcode              
            $errors = $msbuildout | ? { $_ -match ": error" } 
            $errors | write-warning 
            if ($lec -ne 0) {
                write-warning "copying failed build files from $targetdir"
                pwd | write-warning
                Get-ChildItem "$targetdir"            
                copy-item "$targetdir/" "$artifacts/failed-build" -recurse
            }
            $lec | Should Be 0
        }
        
    }

    
}
