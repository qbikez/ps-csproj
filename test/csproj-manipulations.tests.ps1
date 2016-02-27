. $PSScriptRoot\includes.ps1

import-module pester
import-module csproj -DisableNameChecking

#TODO: use https://github.com/pester/Pester/wiki/TestDrive 
Describe "project file manipulation" {
    $null = new-item -ItemType Directory "testdrive:\input\"
    copy-item "$inputdir\test.csproj" "testdrive:\input\"
    copy-item "$inputdir\packages.config" "testdrive:\input\"
    copy-item "$inputdir\packages" "testdrive:\packages" -Recurse
    $testdir = "testdrive:\input" 
    push-location
    cd $testdir
    Context "When replacing projectreference" {        
        
        $csproj = import-csproj "test.csproj"
        $packagename = "Core.Boundaries"
        <#
        It "should build before replacing" {
            Add-MsbuildPath
            $msbuildout = & msbuild 
            $lec = $lastexitcode
            $lec | Should Be 0
        }
        #>
        
        It "csproj Should contain reference to project $packagename" {
            $refs = get-projectreferences $csproj
            $ref = get-projectreferences $csproj | ? { $_.Name -eq $packagename }
            $ref | Should Not BeNullOrEmpty
        }
        It "Should convert properly to nuget" {
            $ref = get-projectreferences $csproj | ? { $_.Name -eq $packagename }
            $nugetref = convertto-nuget $ref "testdrive:\packages"
            $nugetref | Should Not BeNullOrEmpty
            replace-reference $csproj -originalref $ref -newref $nugetref
        }
        
        It "result Project should contain nuget reference to $packagename" {
            $ref = get-nugetreferences $csproj | ? { $_.Name -eq $packagename }
            $ref | Should Not BeNullOrEmpty
        } 
        $ref = get-nugetreferences $csproj
        
        ipmo publishmap
        ipmo pathutils
        $cases = $ref | % { (publishmap\convertto-hashtable $_) }  
        It "nuget reference <name> should have relative path" -TestCases $cases {
            param($name,$path)
                $name | Should Not BeNullOrEmpty
                $path | Should Not BeNullOrEmpty
                Test-IsRelativePath $path | Should Be True 
            
        }

        It "result Project should not contain project  reference to $packagename" {
            $ref = get-projectreferences $csproj | ? { $_.Name -eq $packagename }
            $ref | Should BeNullOrEmpty
        } 
        
        It "packages.config should contain nuget reference" {        
            $p = "packages.config"
            gi $p | Should Not BeNullOrEmpty
            $content = gc $p | out-string
            $conf = [xml]$content
            $conf | Should not BeNullOrEmpty
            $conf.packages | Should not BeNullOrEmpty
            $entry = $conf.packages.package | ? { $_.id -eq $packagename }
            $entry | Should Not BeNullOrEmpty
        }
        It "Should restore properly" {
            $error.Clear()
            & nuget restore -PackagesDirectory "..\packages" 
            $error.Count | Should Be 0
        }
        
        <#
        It "Should Still Compile" {
            Set-TestInconclusive
        }
        #>
    }
    Pop-Location
}
