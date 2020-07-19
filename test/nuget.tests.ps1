BeforeAll {
    . "$PSScriptRoot\includes.ps1"
    . "$PSScriptRoot\..\scripts\lib\imports\msbuild.ps1"

    if (gmo assemblymeta -ErrorAction Ignore) { rmo assemblymeta -Force }
    if (gmo nupkg -ErrorAction Ignore) { rmo nupkg -Force }
    if (gmo semver -ErrorAction Ignore) { rmo semver -Force }

    import-module $psscriptroot\..\src\csproj\csproj.psm1 -DisableNameChecking
    import-module $PSScriptRoot\..\src\semver\semver.psm1
    import-module $PSScriptRoot\..\src\assemblymeta\assemblymeta.psm1
    import-module $PSScriptRoot\..\src\process\process.psm1
    import-module $PSScriptRoot\..\src\nupkg\nupkg.psm1

    $path = $env:Path
    add-msbuildpath
}

Describe "find Nuget packages dir" {
    BeforeAll {
        $targetdir = copy-samples
        $targetdir = $targetdir -replace "TestDrive:", "$TestDrive"
        $csproj = "$targetdir/test/src/Core/Core.vnext/project.json"
        $dir = split-path -parent $csproj
        
        $path = $env:Path
        add-msbuildpath
    }

    AfterAll {
        if ($path) {
            $env:Path = $path 
        }
        else {
            throw 'failed to restore PATH'
        }
    }
    #remove-item "$targetdir/test/nuget.config" 
    It "should find packages dir" {
        In $dir {
            $p = find-packagesdir
            $p | Should -Not -BeNullOrEmpty
            $p | Should -Be "$targetdir\test\packages" 
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
    BeforeAll {
        pushd "TestDrive:"
    }
    AfterAll {
        popd
    }
    It "incrementing part <component> of '<version>' should yield '<expected>'" -testcases $cases {
        param($version, $component, $value, $expected) 
        if ($component -eq $null) { $component = [VersionComponent]::SuffixBuild }

        $r = Update-BuildVersion -version $version -component $component -value $value
        $r | Should -Be $expected
    } 
    It "update build version with custom suffix" {
        $r = Update-BuildVersion -version "1.0.1" -component Suffix -value "sfx"
        $r | Should -Be "1.0.1-sfx"
    }
    It "update build version with custom suffix 2" {
        $r = Update-BuildVersion -version "1.0.1-build001" -component Suffix -value "sfx"
        $r | Should -Be "1.0.1-sfx"
    }
    
}

Describe "Generate nuget for csproj" {
    BeforeAll {
        $targetdir = copy-samples
    }
    
    Context "when nuspec exists" {
        BeforeAll {
            $csproj = "$targetdir/test/src/Core/Core.Library2/Core.Library2.csproj"
            $dir = split-path -parent $csproj
            $project = split-path -leaf $csproj
            
            pushd $dir
        }
        AfterAll {
            popd
        }
        It "Should pack" {
            $nuget = pack-nuget $project -build
            $nuget | Should -Not -BeNullOrEmpty
            test-path $nuget | Should -Be $true  
            $ver = Get-AssemblyMeta "AssemblyInformationalVersion"
            write-host "getting packages version from $nuget"
            $pkgver = get-packageversion $nuget
            $pkgver | Should -Be $ver
        }
            
        It "Should build" {
            invoke "msbuild" 
        } 
        It "Should pack with suffix" {
            $nuget = pack-nuget $project -build -suffix "mysuffix"
            $nuget | Should -Not -BeNullOrEmpty
            test-path $nuget | Should -Be $true  
            $ver = Get-AssemblyMeta "AssemblyInformationalVersion"
            $pkgver = get-packageversion $nuget
            $pkgver | Should -Be $ver
            $ver = Split-Version $pkgver
            $ver.Suffix | Should -Be "mysuffix"
        }
    }
    
    Context "when nuspec does not exist" { 
        BeforeAll {
            $csproj = "$targetdir/test/src/Core/Core.Library1/Core.Library1.csproj"
            $dir = split-path -parent $csproj
            $project = split-path -leaf $csproj
            pushd $dir
        } 
        AfterAll {
            popd
        }
        It "Should build" {
            invoke "msbuild" 
        }            
        It "Should pack without metadata update" {                
            #nuget 3.0 automatically fills description and author with stub data
            #in nuget 2.x this would throw:                
            $nuget = pack-nuget $project
            $nuget | Should -Not -BeNullOrEmpty
            test-path $nuget | Should -Be $true  
            $ver = Get-AssemblyMeta "AssemblyInformationalVersion"
            $pkgver = get-packageversion $nuget
            $pkgver | Should -Be $ver
        }
            
        It "Should pack with metadata update" {    
            Generate-nugetmeta -description "My Description" -author "Me" -version "1.0.1-beta123"
            invoke "msbuild"            
            #nuget 3.0 automatically fills description and author with stub data
            #in nuget 2.x this would throw:                
            $nuget = pack-nuget $project
            $nuget | Should -Not -BeNullOrEmpty
            test-path $nuget | Should -Be $true  
            $ver = Get-AssemblyMeta "AssemblyInformationalVersion"
            $pkgver = get-packageversion $nuget
            $pkgver | Should -Be $ver
            $ver | Should -Be "1.0.1-beta123"
        }
    }
}

Describe "Generate nuget for project.json" {
    BeforeAll {
        $targetdir = copy-samples
        $targetdir = $targetdir -replace "TestDrive:", "$TestDrive"
        $csproj = "$targetdir/test/src/Core/Core.vnext/project.json"
        $dir = split-path -parent $csproj
        $project = split-path -leaf $csproj
        pushd $dir

        $dn = get-dotnetcommand -verbose
        $o = invoke dotnet -verbose -nothrow
        $o = invoke dotnet "--info" -verbose -nothrow
    } 
    AfterAll {
        popd
    }
    #remove-item "$targetdir/test/nuget.config" 
    # OK: dotnet 1.0.0-preview2-1-003177
    # FAILS: 1.0.1
       
    It "Should build" {
        $o = invoke dotnet restore
        $o = invoke dotnet build 
    }    
    It "Should find global.json" {
        $g = find-globaljson
        $g | Should -Not -BeNullOrEmpty
    }
    It "Should pack with build" {
        $nugets = pack-nuget $project -build
        @($nugets) | % {
            $_ | Should -Not -BeNullOrEmpty
            test-path $_ | Should -Be $true  
        } 
    }
                   
    It "Should pack without build" {
        $nugets = pack-nuget $project

        write-host "nugets:"
        $nugets | format-table | out-string | write-host

        @($nugets) | % {
            $_ | Should -Not -BeNullOrEmpty
            test-path $_ | Should -Be $true  
        }

        # expect two files: one with symbols, one without 
        @($nugets).Length | Should -Be 2

        # symbol package should always be second
        $nugets[0].EndsWith(".nupkg") | Should -Be $True
        $nugets[1].EndsWith("symbols.nupkg") | Should -Be $True
                
        #$ver = Get-AssemblyMeta "AssemblyInformationalVersion"
        #$pkgver = get-packageversion $nuget
        #$pkgver | Should -Be $ver
    }
} 

Describe "Handle csproj with project.json" {
    BeforeAll {
        $targetdir = copy-samples
        $targetdir = $targetdir -replace "TestDrive:", "$TestDrive"
        $dir = "$targetdir/test/src/Core/Core.csproj+json/"
        pushd $dir
    }
    AfterAll {
        popd
    }

    It "project.json should win" {
        $ver = Get-AssemblyMeta "AssemblyInformationalVersion"
        $ver | Should -Be "1.2.3"

        $desc = Get-AssemblyMeta "Description"
        $desc | Should -Be "A short json description"
    } 
    It "assembly version Should -Be resolved from AssemblyInfo" {
        $ver = Get-AssemblyMeta "AssemblyVersion"
        $ver | Should -Be "1.0.1"
    }
    It "assembly version Should -Be retrieved from specific file" {
        $ver = Get-AssemblyMeta "AssemblyInformationalVersion"  -assemblyinfo "Properties/AssemblyInfo.cs" 
        $ver | Should -Be "1.0.1"
    }

    It "assembly version Should -Be updated in both files" {
        $newver = update-buildversion -component Patch
        $newver | Should -Be "1.2.4"

        $csver = Get-AssemblyMeta "AssemblyInformationalVersion"  -assemblyinfo "Properties/AssemblyInfo.cs"
        $csvershort = Get-AssemblyMeta "AssemblyVersion"  -assemblyinfo "Properties/AssemblyInfo.cs"
        $jsonver = Get-AssemblyMeta "AssemblyInformationalVersion"  -assemblyinfo "project.json"            
            
        $jsonver | Should -Be $newver
        $csver | Should -Be $newver            
        $csvershort | Should -Be $newver
    }
    
    It "short assembly version should not have prefix" {
        $newver = update-buildversion -verbose
        $newver | Should -Match "1\.2\.4-.*"

        $csver = Get-AssemblyMeta "AssemblyInformationalVersion"  -assemblyinfo "Properties/AssemblyInfo.cs"
        $csvershort = Get-AssemblyMeta "AssemblyVersion"  -assemblyinfo "Properties/AssemblyInfo.cs"
        $jsonver = Get-AssemblyMeta "AssemblyInformationalVersion"  -assemblyinfo "project.json"

            
        $jsonver | Should -Be $newver
        $csver | Should -Be $newver            
        $csvershort | Should -Be "1.2.4"
    }
        
    It "assembly description Should -Be copied from json" {
        $newver = update-buildversion -component Patch
            
        $desc = Get-AssemblyMeta "Description" -assemblyinfo "project.json"
        $csdesc = Get-AssemblyMeta "Description" -assemblyinfo "Properties/AssemblyInfo.cs"

        $desc | Should -Be "A short json description"
        $csdesc | Should -Be "My csproj Description"
    }
}

Describe "Handle .Net Core 2.0 csproj format" {
    BeforeAll {
        $targetdir = copy-samples
        $targetdir = $targetdir -replace "TestDrive:", "$TestDrive"
        $dir = "$targetdir/test/src/Core/Core.2.0/"
        pushd $dir
    }
    AfterAll {
        popd
    }

    It "assembly version Should -Be resolved" {
        $ver = Get-AssemblyMeta "AssemblyVersion"
        $ver | Should -Be "1.0.1"
    }
    It "assembly informational version Should -Be resolved" {
        $ver = Get-AssemblyMeta "AssemblyInformationalVersion"
        $ver | Should -Be "1.0.1-test013-12BCDF"
    }
    It "assembly version Should -Be retrieved from specific file" {
        $ver = Get-AssemblyMeta "AssemblyInformationalVersion"  -assemblyinfo "Core.2.0.csproj" 
        $ver | Should -Be "1.0.1-test013-12BCDF"
    }

    It "assembly version Should -Be updated" {
        $newver = update-buildversion -component Patch
        $newver | Should -Be "1.0.2-test001-12BCDF"

        $ver = Get-AssemblyMeta "AssemblyInformationalVersion"
            
        $ver | Should -Be $newver            
    }

      
    <#
        It "short assembly version should not have prefix" {
            $newver = update-buildversion -verbose
            $newver | Should -Match "1\.2\.4-.*"

            $csver = Get-AssemblyMeta "AssemblyInformationalVersion"  -assemblyinfo "Properties/AssemblyInfo.cs"
            $csvershort = Get-AssemblyMeta "AssemblyVersion"  -assemblyinfo "Properties/AssemblyInfo.cs"
            $jsonver = Get-AssemblyMeta "AssemblyInformationalVersion"  -assemblyinfo "project.json"

            
            $jsonver | Should -Be $newver
            $csver | Should -Be $newver            
            $csvershort | Should -Be "1.2.4"
        }
        
        It "assembly description Should -Be copied from json" {
            $newver = update-buildversion -component Patch
            
            $desc = Get-AssemblyMeta "Description" -assemblyinfo "project.json"
            $csdesc = Get-AssemblyMeta "Description" -assemblyinfo "Properties/AssemblyInfo.cs"

            $desc | Should -Be "A short json description"
            $csdesc | Should -Be "My csproj Description"
        }
        #>
}

