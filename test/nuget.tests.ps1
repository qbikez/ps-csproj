. "$PSScriptRoot\includes.ps1"

import-module pester
import-module csproj
import-module semver



Describe "Nuget Version manipulation" {
    $cases = @(
        @{ version = "1.0.1"; expected = "1.0.1-build001" }
        @{ version = "1.0.0.0"; expected = "1.0.1-build001" }
        @{ version = "1.0.0.*"; expected = "1.0.1-build001" }
        @{ version = "1.2.3.*"; expected = "1.2.4-build001" }
        @{ version = "1.2.*"; expected = "1.3.0-build001" }
        @{ version = "1.*"; expected = "2.0.0-build001" }
    )
    
    It "incrementing part <component> of '<version>' should yield '<expected>'" -testcases $cases {
        param($version, $component, $value, $expected) 
        $r = update-buildversion -version $version
        $r | Should Be $expected 
    }
    
}


Describe "Generate nuget for csproj" {
    $targetdir = copy-samples
    
    Context "when nuspec exists" {        
        $csproj = "$targetdir/test/src/Core/Core.Library2/Core.Library2.csproj"
        $dir = split-path -parent $csproj
        $project = split-path -leaf $csproj
        In $dir {
            It "Should build" {
                invoke "msbuild" 
            }            
            It "Should pack" {
                $nuget = pack-nuget $project
                $nuget | Should Not BeNullOrEmpty
                test-path $nuget | Should Be $true  
                $ver = Get-AssemblyMeta "AssemblyInformationalVersion"
                $pkgver = get-packageversion $nuget
                $pkgver | Should Be $ver
            }
            
        }
    }
    
    Context "when nuspec does not exist" { 
        $csproj = "$targetdir/test/src/Core/Core.Library1/Core.Library1.csproj"
        $dir = split-path -parent $csproj
        $project = split-path -leaf $csproj
        In $dir {
            It "Should build" {
                invoke "msbuild" 
            }            
            It "Should pack without metadata update" {                
                #nuget 3.0 automatically fills description and author with stub data
                #in nuget 2.x this would throw:                
                $nuget = pack-nuget $project
                $nuget | Should Not BeNullOrEmpty
                test-path $nuget | Should Be $true  
                $ver = Get-AssemblyMeta "AssemblyInformationalVersion"
                $pkgver = get-packageversion $nuget
                $pkgver | Should Be $ver
            }
            
               It "Should pack with metadata update" {    
                Generate-nugetmeta -description "My Description" -author "Me" -version "1.0.1-beta123"
                invoke "msbuild"            
                #nuget 3.0 automatically fills description and author with stub data
                #in nuget 2.x this would throw:                
                $nuget = pack-nuget $project
                $nuget | Should Not BeNullOrEmpty
                test-path $nuget | Should Be $true  
                $ver = Get-AssemblyMeta "AssemblyInformationalVersion"
                $pkgver = get-packageversion $nuget
                $pkgver | Should Be $ver
                $ver | Should Be "1.0.1-beta123"
            }
            
        }
    }
}