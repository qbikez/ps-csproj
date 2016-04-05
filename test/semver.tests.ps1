. "$PSScriptRoot\includes.ps1"

import-module pester
import-module semver


Describe "parse version" {
    $cases = @(
        
        @{ version = "1.0.1-build123"; major = 1; minor = 0; patch = 1; build = 123; branch = "build" }
        @{ version = "1.0.1-build.123"; major = 1; minor = 0; patch = 1; build = 123; branch = "build" }
        @{ version = "1.0.1-build123"; major = 1; minor = 0; patch = 1; build = 123; branch = "build" }
        @{ version = "1.0.1-featureabc.123"; major = 1; minor = 0; patch = 1; build = 123; branch = "featureabc" }
        @{ version = "1.0.1-feature-abc.123"; major = 1; minor = 0; patch = 1; build = 123; branch = "feature-abc" }
        @{ version = "1.0.1-feature-abc123"; major = 1; minor = 0; patch = 1; build = 123; branch = "feature-abc" }
        @{ version = "1.0.1-featureabc.123+4af3d"; major = 1; minor = 0; patch = 1; build = 123; branch = "featureabc"; rev = "4af3d" }
        @{ version = "1.0.1-rc1_2016_01_01.123"; branch = "rc1_2016_01_01"; build = 123 }
    )
    It "parsing '<version>' should yield major=<major> minor=<minor> patch=<patch> branch=<branch> buildno=<build> rev=<rev>" -testcases $cases {
        param($version, $major, $minor, $patch, $branch, $build, $rev) 
        
        $ver = Split-Version $version
        if ($major -ne $null) { $ver.major | Should Be $major }
        if ($minor -ne $null) { $ver.minor | Should Be $minor }
        if ($patch -ne $null) { $ver.patch | Should Be $patch }
        if ($branch -ne $null) { $ver.branchname | Should Be $branch }
        if ($build -ne $null) { $ver.BuildNum | Should Be $build }
        if ($rev -ne $null) { $ver.revision | Should Be $rev }
    }
}



Describe "update version" {
    $cases = @(        
        # compatibility mode:
        # branch: 10chars
        # rev: 6chars
        # revseparator: -
        @{ version = "1.0.1-alpha-build.123"; component = [VersionComponent]::SuffixBuild; compatibility = $true; expected = "1.0.1-alpha-buil124" }
        @{ version = "1.0.1-alpha_2016_01_01.123"; component = [VersionComponent]::SuffixBuild; compatibility = $true; expected = "1.0.1-alpha2016-124" }
        @{ version = "1.0.1-build123"; component = [VersionComponent]::SuffixBuild; expected = "1.0.1-build.124" }
        @{ version = "1.0.1"; component = [VersionComponent]::Patch; expected = "1.0.2" }
        @{ version = "1.0.1"; component = [VersionComponent]::Minor; expected = "1.1.0" }
        @{ version = "1.0.1"; component = [VersionComponent]::Major; expected = "2.0.0" }        
        @{ version = "1.0.1-build.123"; component = [VersionComponent]::SuffixBuild; expected = "1.0.1-build.124" }
        @{ version = "1.0.1-alpha-build.123"; component = [VersionComponent]::SuffixBuild; expected = "1.0.1-alpha-build.124" }
        @{ version = "1.0.1-alpha-build.123+12abc"; component = [VersionComponent]::SuffixBuild; expected = "1.0.1-alpha-build.124+12abc" }
        @{ version = "1.0.1-alpha-build.123+12abc"; component = [VersionComponent]::SuffixRevision; value = "abc12ff"; expected = "1.0.1-alpha-build.123+abc12ff" }
        @{ version = "1.0.1-alpha-build.123"; component = [VersionComponent]::SuffixRevision; value = "abc12ff"; expected = "1.0.1-alpha-build.123+abc12ff" }
        @{ version = "1.0.1-build.123"; component = [VersionComponent]::Patch; expected = "1.0.2-build.001" }
        @{ version = "1.0.1-alpha-build.123"; component = [VersionComponent]::Patch; expected = "1.0.2-alpha-build.001" }
        
    )
    
    It "incrementing part <component> of '<version>' should yield '<expected>'" -testcases $cases {
        param($version, $component, $value, $expected, $compatibility)
        if ($compatibility -eq $null) { $compatibility = $false } 
        $newver = update-version -ver $version -component $component -value $value -compatibilityMode:$compatibility
        $newver | Should Be $expected
        #if ($compatibility) { $newver.Suffix.Length | Should Be }
         
    }
    
}
