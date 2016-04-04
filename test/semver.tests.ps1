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
        @{ version = "1.0.1-featureabc.123+4af3d"; major = 1; minor = 0; patch = 1; build = 123; branch = "featureabc"; rev = "4af3d" }
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
        
        @{ version = "1.0.1-build123"; component = [VersionComponent]::SuffixBuild; expected = "1.0.1-build.124" }
        @{ version = "1.0.1"; component = [VersionComponent]::Patch; expected = "1.0.2" }
        @{ version = "1.0.1"; component = [VersionComponent]::Minor; expected = "1.1.0" }
        @{ version = "1.0.1"; component = [VersionComponent]::Major; expected = "2.0.0" }        
        @{ version = "1.0.1-build.123"; component = [VersionComponent]::SuffixBuild; expected = "1.0.1-build.124" }
        @{ version = "1.0.1-alpha-build.123"; component = [VersionComponent]::SuffixBuild; expected = "1.0.1-alpha-build.124" }
        @{ version = "1.0.1-alpha-build.123+12abc"; component = [VersionComponent]::SuffixBuild; expected = "1.0.1-alpha-build.124+12abc" }
        @{ version = "1.0.1-alpha-build.123+12abc"; component = [VersionComponent]::SuffixRevision; value = "abc12ff"; expected = "1.0.1-alpha-build.123+abc12ff" }
        @{ version = "1.0.1-build.123"; component = [VersionComponent]::Patch; expected = "1.0.2-build.001" }
        @{ version = "1.0.1-alpha-build.123"; component = [VersionComponent]::Patch; expected = "1.0.2-alpha-build.001" }
    )
    
    It "incrementing part <component> of '<version>' should yield '<expected>'" -testcases $cases {
        param($version, $component, $value, $expected) 
        update-version -ver $version -component $component -value $value | Should Be $expected 
    }
    
}
