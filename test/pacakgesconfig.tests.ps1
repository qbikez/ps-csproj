BeforeAll {
    . $PSScriptRoot\includes.ps1

    if (get-module csproj) { remove-module csproj -force }
    import-module $psscriptroot\..\src\csproj\csproj.psm1 -DisableNameChecking
}

Describe "packages config manipulation" {
    BeforeAll {
        $xml = @'
    <?xml version="1.0" encoding="utf-8"?>
    <packages>
      <package id="Microsoft.Bcl" version="1.1.10" targetFramework="portable-net45+win+wp80+MonoAndroid10+xamarinios10+MonoTouch10" />
      <package id="Microsoft.Bcl.Build" version="1.0.14" targetFramework="portable-net45+win+wp80+MonoAndroid10+xamarinios10+MonoTouch10" />
      <package id="Newtonsoft.Json" version="6.0.8" targetFramework="portable-net45+win+wp80+MonoAndroid10+xamarinios10+MonoTouch10" />
    </packages>
'@
    }
    Context "When loaded from string" {
        BeforeAll {
            $conf = get-packagesconfig $xml
        }
        
        It "Should load properly" {
           # $conf | Should -Not -Be $null # BeNullOrEmpty # why does it throw for a valid object? 
           $conf.xml | Should -Not -BeNullOrEmpty
           $conf -isnot [Object[]] | Should -Be True
        }
        
        It "Should List all packages" {
            $conf.packages | Should -Not -BeNullOrEmpty
            $conf.packages.Count | Should -Be 3
        }
        
        
        $ids =  @("Microsoft.Bcl","Microsoft.Bcl.Build", "Newtonsoft.Json")
        
        $cases = $ids | % { @{ Id = $_ } }
        It "Should Contain <id>" -TestCases $cases {
            param($id)
            $conf.packages | ? { $_.Id -eq $id } | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "When adding new dependency" {
        BeforeAll {
            $conf = get-packagesconfig $xml    
            $id = "Test.Dependency"
            $version = "1.0"
        }
        
        It "should contain added id" {
            $conf.packages | Should -Not -BeNullOrEmpty
            $oldcount = $conf.packages.count
            add-packagetoconfig $conf $id $version 
            $conf.packages.count | Should -Be ($oldcount + 1)
            $conf.packages | ? { $_.id -eq $id } | Should -Not -BeNullOrEmpty            
        }
    }
    
    Context "When adding existing dependency" {
        BeforeAll {
            $conf = get-packagesconfig $xml
            $id = "Newtonsoft.Json"
            $version = "1.0"
        }
        
        It "Should already contain added dependency" {
            $conf.packages | ? { $_.id -eq $id } | Should -Not -BeNullOrEmpty             
        }
        It "Should -Throw by default" {
             { 
                 add-packagetoconfig $conf $id  $version
                 } | Should -Throw
        }
        
        It "Should pass when using -ifnotexists" {
             { add-packagetoconfig $conf $id $version -ifnotexists } | Should -Not -Throw
        }
        
        It "should contain added existing id" {
            add-packagetoconfig $conf $id $version  -ifnotexists
            $conf.packages | ? { $_.Id -eq $id } | Should -Not -BeNullOrEmpty            
        }
    }
    
    Context "When removing dependency" {
        BeforeAll {
            $conf = get-packagesconfig $xml
            $id = "Newtonsoft.Json"
            $version = "1.0"
        }
  
        It "should not contain removed id" {
            remove-packagefromconfig $conf $id
            $conf.packages | ? { $_.Id -eq $id } | Should -BeNullOrEmpty            
        }
    }
    
    Context "When removing non-existing dependency" {
        BeforeAll {
            $conf = get-packagesconfig $xml    
            $id = "Test.Dependency"
        }
         
        It "Should -Throw by default" {
             { remove-packagefromconfig $conf $id  } | Should -Throw 
        }
    }
    
}

Describe "packages config file" {
    Context "When referencing non-existing file" {
        BeforeAll {
            test-path "TestDrive:\packages.config" | Should -Be $false
        }
        It "should create if -createifnotexists is specified" {
            $pkg = get-packagesconfig "TestDrive:\packages.config" -createifnotexists
            test-path "TestDrive:\packages.config" | Should -Be $true
            $pkg | Should -Not -BeNullOrEmpty
            $pkg.xml | Should -Not -Be $null
        }
        It "should not overwrite if -createifnotexists is specified" {
            if (test-path "TestDrive:\packages.config") {
                remove-item "TestDrive:\packages.config"
            }
            $xml = '<?xml version="1.0" encoding="utf-8"?><packages><package id="a.test.1" /></packages>'
            $xml | out-file "TestDrive:\packages.config" -encoding utf8
            
            $pkg = get-packagesconfig "TestDrive:\packages.config" -createifnotexists
            $pkg | Should -Not -BeNullOrEmpty
            $pkg.xml | Should -Not -Be $null
            get-content "TestDrive:\packages.config" | Should -Be $xml
        }
    }
} 