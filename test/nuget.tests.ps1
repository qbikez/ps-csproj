. "$PSScriptRoot\includes.ps1"

import-module pester
import-module csproj
import-module semver


Describe "Version manipulation" {
    $cases = @(
        @{ version = "1.0.1"; component = [VersionComponent]::Patch; expected = "1.0.2" }
        @{ version = "1.0.1"; component = [VersionComponent]::Minor; expected = "1.1.0" }
        @{ version = "1.0.1"; component = [VersionComponent]::Major; expected = "2.0.0" }
        @{ version = "1.0.1-build123"; component = [VersionComponent]::SuffixBuild; expected = "1.0.1-build124" }
        @{ version = "1.0.1-alpha-build123"; component = [VersionComponent]::SuffixBuild; expected = "1.0.1-alpha-build124" }
        @{ version = "1.0.1-alpha-build123+12abc"; component = [VersionComponent]::SuffixBuild; expected = "1.0.1-alpha-build124+12abc" }
        @{ version = "1.0.1-alpha-build123+12abc"; component = [VersionComponent]::SuffixRevision; value = "abc12ff"; expected = "1.0.1-alpha-build123+abc12ff" }
        @{ version = "1.0.1-build123"; component = [VersionComponent]::Patch; expected = "1.0.2-build123" }
    )
    
    It "incrementing part <component> of '<version>' should yield '<expected>'" -testcases $cases {
        param($version, $component, $value, $expected) 
        increment-version -ver $version -component $component -value $value | Should Be $expected 
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