. "$PSScriptRoot\..\includes.ps1"

Import-Module pester
import-module csproj

Describe "Converting Project reference to nuget" {
    copy-item "$inputdir\test" "testdrive:\test" -recurse
    copy-item "$inputdir\packages" "testdrive:\packages" -recurse
        
    $slnfile = "testdrive:\test\sln\Sample.Solution\Sample.Solution.sln"
    $slndir = split-path -parent $slnfile
    $packagesdir = "testdrive:\packages"
    
    $sln = import-sln $slnfile
    
    Context "When loading sln file" {
        $projectName = "Core.Library1"
    
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
            $p.path | Should be "..\..\src\Core\Core.Library1\Core.Library1.csproj"
        }
        
        It "Should list all references to $projectname" {
            $refs = get-referencesto $sln $projectname -verbose
            $refs | Should Not BeNullOrEmpty
        }
    }
    
    Context "When converting project with matching nuget" {
        $projectname = "Core.Library1"
        $null = new-item "testdrive:\packages\$projectname.1.0.1\lib\" -type directory
        $null = new-item "testdrive:\packages\$projectname.1.0.1\lib\$projectname.dll" -type file 
        
        $oldrefs = get-referencesto $sln $projectname -verbose
        $r = $sln | convert-projectReferenceToNuget -project "$projectname" -verbose -packagesdir $packagesdir
        
        $r
        
        It "should not leave any project reference" {
            $refs = get-referencesto $sln $projectname -verbose
            $refs | ? { $_.type -eq "project" }  | Should BeNullOrEmpty
            
            $refs | Should Not BeNullOrEmpty
            
            $nugetrefs = $refs | ? { $_.type -eq "nuget" }  
            $nugetrefs | Should Not BeNullOrEmpty
            
            $refs.count | Should Be $oldrefs.Count
            $nugetrefs.Count | Should Be $refs.Count
        }
        
        It "converted references should exist in packages.config" {
            $refs = get-referencesto $sln $projectname -verbose
            $nugetrefs = $refs | ? { $_.type -eq "nuget" }  
            foreach($n in $nugetrefs) {
                $dir = split-path $n.projectpath
                $pkg = get-packagesconfig "$dir/packages.config"
                $pkg | Should Not BeNullOrEmpty
                $pkg.packages | Should Not BeNullOrEmpty
                $pkg.packages | ? { $_.id -eq $n.name } | Should Not BeNullOrEmpty
            }
        }
        
    }
}