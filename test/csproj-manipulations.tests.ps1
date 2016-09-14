. $PSScriptRoot\includes.ps1

import-module pester
import-module csproj -DisableNameChecking
import-module pathutils

#TODO: use https://github.com/pester/Pester/wiki/TestDrive 
Describe "project file manipulation" {
    $null = new-item -ItemType Directory "testdrive:\input\"
    copy-item "$inputdir\test.csproj" "testdrive:\input\"
    copy-item "$inputdir\packages.config" "testdrive:\input\"
    copy-item "$inputdir\packages" "testdrive:\packages" -Recurse
    copy-item "$inputdir\test" "testdrive:\input\test" -Recurse
    $testdir = "testdrive:\input" 
    In $testdir {

    Context "When project reference version differs from packages.config" {
        $csproj = import-csproj "test\src\Core\Core.Lib3\Core.Lib3.csproj"
        $pkgconfig =  $conf = get-packagesconfig "test\src\Core\Core.Lib3\packages.config"       

        It "Should detect the difference" {
            $refs = get-nugetreferences $csproj
            $incorect = @()
            foreach($pkgref in $pkgconfig.packages) {
                $ref = $refs | ? { $_.ShortName -eq $pkgref.id }
                if ($ref -eq $null) {
                    write-warning "missing csproj reference for package $($pkgref.id)"
                }
                if ($ref.path -notmatch "$($pkgref.version)") {
                    # bad reference in csproj? try to detect current version
                    if ($ref.path -match "$($pkgref.id).(?<version>.*?)\\") {
                        Write-Warning "version of package '$($pkgref.id)' in csproj: '$($matches["version"])' doesn't match packages.config version: '$($pkgref.version)'"
                        #fix it
                        #$ref.path = $ref.path -replace "$($pkgref.id).(?<version>.*?)\\","$($pkgref.id).$($pkgref.version)\"
                        #$ref.Node.HintPath = $ref.path
                        #$csproj.Save() 
                        $incorect += @($pkgref.id)
                    }
                }
            }

            $incorect.length | Should Be 1
            $incorect[0] | Should Be "log4net"
        }

        It "Should fix the difference" {
            repair-csprojpaths $csproj -reporoot "testdrive:\"
        }

        It "difference should be fixed" {
            $refs = get-nugetreferences $csproj
            $incorect = @()
            foreach($pkgref in $pkgconfig.packages) {
                $ref = $refs | ? { $_.ShortName -eq $pkgref.id }
                if ($ref -eq $null) {
                    write-warning "missing csproj reference for package $($pkgref.id)"
                }
                if ($ref.path -notmatch "$($pkgref.version)") {
                    # bad reference in csproj? try to detect current version
                    if ($ref.path -match "$($pkgref.id).(?<version>.*?)\\") {
                        Write-Warning "version of package '$($pkgref.id)' in csproj: '$($matches["version"])' doesn't match packages.config version: '$($pkgref.version)'"
                        #fix it
                        #$ref.path = $ref.path -replace "$($pkgref.id).(?<version>.*?)\\","$($pkgref.id).$($pkgref.version)\"
                        #$ref.Node.HintPath = $ref.path
                        #$csproj.Save() 
                        $incorect += @($pkgref.id)
                    }
                }
            }

            $incorect.length | Should Be 0
        }
    }
<#
    Context "When replacing projectreference" {        
        
        $csproj = import-csproj "test.csproj"
        $packagename = "Core.Boundaries"
        
        #It "should build before replacing" {
        #    Add-MsbuildPath
        #    $msbuildout = & msbuild 
        #    $lec = $lastexitcode
        #    $lec | Should Be 0
        #}
        
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
        $cases = $ref | % { 
            (publishmap\convertto-hashtable $_)
         }  
        It "nuget reference <name> should have relative path" -TestCases $cases {
            param($name,$path)
                $name | Should Not BeNullOrEmpty
                $path | Should Not BeNullOrEmpty
                Test-IsPathRelative $path | Should Be True 
            
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
            $nugetout = & nuget restore -NoCache -PackagesDirectory "..\packages" 2>&1
            if ($lastexitcode -ne 0) {
                $nugetout | % {Write-Warning $_}
            }
            $lastexitcode | Should be 0
        }
        
        
        # It "Should Still Compile" {
        #     Set-TestInconclusive
        # }
    }
#>
    
    }
}
