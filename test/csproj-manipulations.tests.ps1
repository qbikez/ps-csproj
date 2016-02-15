. $PSScriptRoot\includes.ps1

import-module pester
import-module csproj -DisableNameChecking

#TODO: use https://github.com/pester/Pester/wiki/TestDrive 
Describe "project file manipulation" {
    $null = new-item -ItemType Directory "testdrive:\input\"
    copy-item "$inputdir\test.csproj" "testdrive:\input\"
    copy-item "$inputdir\packages.config" "testdrive:\input\"
    $testdir = "testdrive:\input" 
    push-location
    cd $testdir
    Context "When replacing projectreference" {        
        $csproj = import-csproj "test.csproj"
        $packagename = "Common.Log.Interfaces"
        It "packages.config should contain nuget reference" {        
            $p = "packages.config"
            gi $p | Should Not BeNullOrEmpty
            $content = gc $p | out-string
            $conf = [xml]$content
            $conf | Should not BeNullOrEmpty
            $conf.packages | Should not BeNullOrEmpty
            $entry = $conf.packages.package | ? { $_.id -eq $package }
            $entry | Should Not BeNullOrEmpty
        }
        It "Should restore properly" {
            $error.Clear()
            $r = & nuget restore -PackagesDirectory "packages"
            $error.Count | Should Be 0
        }
        It "Should Still Compile" {
        }
    }
    Pop-Location
}
