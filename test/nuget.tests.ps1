. "$PSScriptRoot\includes.ps1"

if (gmo assemblymeta -ErrorAction Ignore) { rmo assemblymeta -Force }
if (gmo nupkg -ErrorAction Ignore) { rmo nupkg -Force }
if (gmo semver -ErrorAction Ignore) { rmo semver -Force }

import-module $psscriptroot\..\src\csproj\csproj.psm1 -DisableNameChecking
import-module $PSScriptRoot\..\src\semver\semver.psm1
import-module $PSScriptRoot\..\src\assemblymeta\assemblymeta.psm1
import-module $PSScriptRoot\..\src\process\process.psm1
import-module $PSScriptRoot\..\src\nupkg\nupkg.psm1

Describe "find Nuget packages dir" {
    $targetdir = copy-samples
    $targetdir = $targetdir -replace "TestDrive:","$testdrive"
    $csproj = "$targetdir/test/src/Core/Core.vnext/project.json"
    $dir = split-path -parent $csproj
    
    #remove-item "$targetdir/test/nuget.config" 
    It "should find packages dir" {
        In $dir {
                $p = find-packagesdir
                $p | Should not BeNullOrEmpty
                $p | should be "$targetdir\test\packages" 
        }
    }
}


Describe "Nuget Version manipulation" {
    $cases = @(   
        @{ version = "1.2.*"; component = "Patch"; value = "33"; expected = "1.2.33" }
        @{ version = "1.2.*"; expected = "1.3.0-build001" }
        @{ version = "1.2.3.*"; expected = "1.2.4-build001" }    
        @{ version = "1.0.1"; expected = "1.0.1-build001" }
        @{ version = "1.0.0.0"; expected = "1.0.1-build001" }
        @{ version = "1.0.0.*"; expected = "1.0.1-build001" }
        @{ version = "1.*"; expected = "2.0.0-build001" }      
    )
    In "TestDrive:" {      
        It "incrementing part <component> of '<version>' should yield '<expected>'" -testcases $cases   {
            param($version, $component, $value, $expected) 
            if ($component -eq $null) { $component = [VersionComponent]::SuffixBuild }

            $r = update-buildversion -version $version -component $component -value $value
            $r | Should Be $expected
        } 
        It "update build version with custom suffix" {
            $r = update-buildversion -version "1.0.1" -component Suffix -value "sfx"
            $r | Should Be "1.0.1-sfx"
        }
        It "update build version with custom suffix 2" {
            $r = update-buildversion -version "1.0.1-build001" -component Suffix -value "sfx"
            $r | Should Be "1.0.1-sfx"
        }
    }
}


Describe "Generate nuget for csproj" {
    $targetdir = copy-samples
    
    Context "when nuspec exists" {        
        $csproj = "$targetdir/test/src/Core/Core.Library2/Core.Library2.csproj"
        $dir = split-path -parent $csproj
        $project = split-path -leaf $csproj
        In $dir {
                     
            It "Should pack" {
                $nuget = pack-nuget $project -build
                $nuget | Should Not BeNullOrEmpty
                test-path $nuget | Should Be $true  
                $ver = Get-AssemblyMeta "AssemblyInformationalVersion"
                write-host "getting packages version from $nuget"
                $pkgver = get-packageversion $nuget
                $pkgver | Should Be $ver
            }
            
            It "Should build" {
                invoke "msbuild" 
            } 
            It "Should pack with suffix" {
                $nuget = pack-nuget $project -build -suffix "mysuffix"
                $nuget | Should Not BeNullOrEmpty
                test-path $nuget | Should Be $true  
                $ver = Get-AssemblyMeta "AssemblyInformationalVersion"
                $pkgver = get-packageversion $nuget
                $pkgver | Should Be $ver
                $ver = Split-Version $pkgver
                $ver.Suffix | Should Be "mysuffix"
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



Describe "Generate nuget for project.json" {
    $targetdir = copy-samples
    $targetdir = $targetdir -replace "TestDrive:","$testdrive"
    $csproj = "$targetdir/test/src/Core/Core.vnext/project.json"
    $dir = split-path -parent $csproj
    $project = split-path -leaf $csproj
    #remove-item "$targetdir/test/nuget.config" 
     In $dir { 
            # OK: dotnet 1.0.0-preview2-1-003177
            # FAILS: 1.0.1
            $dn = get-dotnetcommand -verbose
            $o = invoke dotnet -verbose -nothrow
            $o = invoke dotnet "--info" -verbose -nothrow
            It "Should build" {
                $o = invoke dotnet restore
                $o = invoke dotnet build 
            }    
            It "Should find global.json" {
                $g  = find-globaljson
                $g | Should Not BeNullOrEmpty
            }
            It "Should pack with build" {
                $nugets = pack-nuget $project -build
                @($nugets) | % {
                    $_ | Should Not BeNullOrEmpty
                    test-path $_ | Should Be $true  
                } 
            }
                   
            It "Should pack without build" {
                $nugets = pack-nuget $project

                write-host "nugets:"
                $nugets | format-table | out-string | write-host

                @($nugets) | % {
                    $_ | Should Not BeNullOrEmpty
                    test-path $_ | Should Be $true  
                }

                # expect two files: one with symbols, one without 
                @($nugets).Length | Should Be 2

                # symbol package should always be second
                $nugets[0].EndsWith(".nupkg") | Should Be $True
                $nugets[1].EndsWith("symbols.nupkg") | Should Be $True
                
                #$ver = Get-AssemblyMeta "AssemblyInformationalVersion"
                #$pkgver = get-packageversion $nuget
                #$pkgver | Should Be $ver
            }
          
        }
} 



Describe "Handle csproj with project.json" {
    $targetdir = copy-samples
    $targetdir = $targetdir -replace "TestDrive:","$testdrive"
    $dir = "$targetdir/test/src/Core/Core.csproj+json/"

     In $dir {
        It "project.json should win" {
            $ver = Get-AssemblyMeta "AssemblyInformationalVersion"
            $ver | Should Be "1.2.3"

            $desc = Get-AssemblyMeta "Description"
            $desc | Should Be "A short json description"
        } 
        It "assembly version should be resolved from AssemblyInfo" {
            $ver = Get-AssemblyMeta "AssemblyVersion"
            $ver | Should Be "1.0.1"
        }
        It "assembly version should be retrieved from specific file" {
            $ver = Get-AssemblyMeta "AssemblyInformationalVersion"  -assemblyinfo "Properties/AssemblyInfo.cs" 
            $ver | Should Be "1.0.1"
        }

        It "assembly version should be updated in both files" {
            $newver = update-buildversion -component Patch
            $newver | Should Be "1.2.4"

            $csver = Get-AssemblyMeta "AssemblyInformationalVersion"  -assemblyinfo "Properties/AssemblyInfo.cs"
            $csvershort = Get-AssemblyMeta "AssemblyVersion"  -assemblyinfo "Properties/AssemblyInfo.cs"
            $jsonver = Get-AssemblyMeta "AssemblyInformationalVersion"  -assemblyinfo "project.json"            
            
            $jsonver | Should Be $newver
            $csver | Should Be $newver            
            $csvershort | Should Be $newver
        }
    
        It "short assembly version should not have prefix" {
            $newver = update-buildversion -verbose
            $newver | Should Match "1\.2\.4-.*"

            $csver = Get-AssemblyMeta "AssemblyInformationalVersion"  -assemblyinfo "Properties/AssemblyInfo.cs"
            $csvershort = Get-AssemblyMeta "AssemblyVersion"  -assemblyinfo "Properties/AssemblyInfo.cs"
            $jsonver = Get-AssemblyMeta "AssemblyInformationalVersion"  -assemblyinfo "project.json"

            
            $jsonver | Should Be $newver
            $csver | Should Be $newver            
            $csvershort | Should Be "1.2.4"
        }
        
        It "assembly description should be copied from json" {
            $newver = update-buildversion -component Patch
            
            $desc = Get-AssemblyMeta "Description" -assemblyinfo "project.json"
            $csdesc = Get-AssemblyMeta "Description" -assemblyinfo "Properties/AssemblyInfo.cs"

            $desc | Should Be "A short json description"
            $csdesc | Should Be "My csproj Description"
        }
     }
     
}

Describe "Handle .Net Core 2.0 csproj format" {
    $targetdir = copy-samples
    $targetdir = $targetdir -replace "TestDrive:","$testdrive"
    $dir = "$targetdir/test/src/Core/Core.2.0/"

     In $dir {       
        It "assembly version should be resolved" {
            $ver = Get-AssemblyMeta "AssemblyVersion"
            $ver | Should Be "1.0.1"
        }
        It "assembly informational version should be resolved" {
            $ver = Get-AssemblyMeta "AssemblyInformationalVersion"
            $ver | Should Be "1.0.1-test013-12BCDF"
        }
        It "assembly version should be retrieved from specific file" {
            $ver = Get-AssemblyMeta "AssemblyInformationalVersion"  -assemblyinfo "Core.2.0.csproj" 
            $ver | Should Be "1.0.1-test013-12BCDF"
        }

        It "assembly version should be updated" {
            $newver = update-buildversion -component Patch
            $newver | Should Be "1.0.2-test001-12BCDF"

            $ver = Get-AssemblyMeta "AssemblyInformationalVersion"
            
            $ver | Should Be $newver            
        }

      
    <#
        It "short assembly version should not have prefix" {
            $newver = update-buildversion -verbose
            $newver | Should Match "1\.2\.4-.*"

            $csver = Get-AssemblyMeta "AssemblyInformationalVersion"  -assemblyinfo "Properties/AssemblyInfo.cs"
            $csvershort = Get-AssemblyMeta "AssemblyVersion"  -assemblyinfo "Properties/AssemblyInfo.cs"
            $jsonver = Get-AssemblyMeta "AssemblyInformationalVersion"  -assemblyinfo "project.json"

            
            $jsonver | Should Be $newver
            $csver | Should Be $newver            
            $csvershort | Should Be "1.2.4"
        }
        
        It "assembly description should be copied from json" {
            $newver = update-buildversion -component Patch
            
            $desc = Get-AssemblyMeta "Description" -assemblyinfo "project.json"
            $csdesc = Get-AssemblyMeta "Description" -assemblyinfo "Properties/AssemblyInfo.cs"

            $desc | Should Be "A short json description"
            $csdesc | Should Be "My csproj Description"
        }
        #>
     }
     
}


