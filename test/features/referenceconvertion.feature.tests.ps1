. "$PSScriptRoot\..\includes.ps1"

Import-Module pester
import-module csproj

Describe "Converting Project reference to nuget" {
    $slnfile = "$inputdir\test\sln\Sample.Solution\Sample.Solution.sln"
    $slndir = split-path -parent $slnfile
    $packagesdir = "$inputdir\packages"
    
    $sln = import-sln $slnfile
    
    Context "When loading sln file" {
        $projectName = "Console1"
    
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
        
        It "reference to $projectName should be a project reference" {
            $projects = $sln | get-slnprojects
            $p = $projects | ? { $_.Name -eq $projectName }
            $p | Should Not BeNullOrEmpty
            $p.path | Should be "..\..\src\Console\Console1\Console1.csproj"
        }
    }
    
    Context "When converting projects" {
        $sln | convert-projectReferenceToNuget -projectName "Console1" -packagesdir $packagesdir
    
        It "should " {
            
        }
        
    }
}