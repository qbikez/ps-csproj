. "$psscriptroot\..\includes.ps1"

import-module pester
import-module csproj

Describe "verify solution project set" {
    $slnfile = "$inputdir/test/sln/Sample.Solution/Sample.Solution.sln"
    It "Should return a tree of all projects and their dependencies" {
        $sln = import-sln $slnfile
        $deps = get-slndependencies $sln
        $deps | Should Not BeNullOrEmpty
        $deps.Length | Should Be 3    
    }
    
    $slnfile = "$inputdir/test/sln/Sample.Solution.Bad/Sample.Solution.Bad.sln"    
    It "Should report missing projects" {
        $sln = import-sln $slnfile
        $valid,$missing = test-slndependencies $sln
        $valid | Should Be $false
        $missing | Should Not BeNullOrEmpty
        $missing.Length | Should Be 1
    }
 }


Describe "fix a project with missing references" {
    Context "when initializing" {
        It "Should scan repo root for csproj files" {
            Set-TestInconclusive
        }
        It "Should scan packages dir for nuget packages" {
            Set-TestInconclusive
        }
        It "Should scan chosen packages source for nuget packages"{
            Set-TestInconclusive
        }
    }
    Context "When a matching csproj can be found in repo directory"{
        It "Should replace reference path with a valid csproj" {
            Set-TestInconclusive
        }
    }
    Context "When a matching nuget can be found in one of the sources" {
        It "Should repace reference with a valid nuget" {
            Set-TestInconclusive
        }
    }
}
