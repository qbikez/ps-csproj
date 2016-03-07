. "$PSScriptRoot\includes.ps1"

import-module pester
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
        @{ version = "1.0.1-build123"; component = [VersionComponent]::Patch; expected = "1.0.2-build001" }
        @{ version = "1.0.1-alpha-build123"; component = [VersionComponent]::Patch; expected = "1.0.2-alpha-build001" }
    )
    
    It "incrementing part <component> of '<version>' should yield '<expected>'" -testcases $cases {
        param($version, $component, $value, $expected) 
        update-version -ver $version -component $component -value $value | Should Be $expected 
    }
    
}
