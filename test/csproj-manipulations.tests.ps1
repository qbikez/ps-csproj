. $PSScriptRoot\includes.ps1

#TODO: use https://github.com/pester/Pester/wiki/TestDrive 
Describe "project file manipulation" {
    copy-item $inputdir testdrive:\input -Recurse
    $testdir = testdrive:\input 
    Context "When replacing projectreference" {        
        $csproj = import-csproj $xml

        It "packages.config should contain nuget reference" {            
        }
        It "Should restore properly" {
        }
        It "Should Still Compile" {
        }
    }
}
