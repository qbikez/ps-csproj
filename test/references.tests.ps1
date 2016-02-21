. $PSScriptRoot\includes.ps1


$xml = invoke-command { @'
<?xml version="1.0" encoding="utf-8"?>
<Project ToolsVersion="12.0" DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <ItemGroup>
    <Reference Include="Castle.Core">
      <HintPath>..\..\..\..\packages\Castle.Core.3.3.3\lib\net45\Castle.Core.dll</HintPath>
    </Reference>   
    <Reference Include="Common.Configuration.log4net, Version=2.0.0.0, Culture=neutral, processorArchitecture=MSIL">
      <SpecificVersion>False</SpecificVersion>
      <HintPath>..\..\..\..\packages\Common.Configuration.log4net.2.0.0-beta1\lib\net451\Common.Configuration.log4net.dll</HintPath>
      <Private>True</Private>
    </Reference>
    <Reference Include="Microsoft.CSharp" />
  </ItemGroup>
  <ItemGroup>   
    <Compile Include="App_Start\BundleConfig.cs" />    
  </ItemGroup>
  <ItemGroup>
    <Folder Include="App_Data\" />
  </ItemGroup>  
  <ItemGroup>
    <ProjectReference Include="..\..\Core\Core.Client\Core.Client.csproj">
      <Project>{1ed821b1-89d1-4383-9e3a-ad7161b6640a}</Project>
      <Name>Core.Client</Name>
    </ProjectReference>
    <ProjectReference Include="..\..\Core\Core.Interface\Core.Interface.csproj">
      <Project>{32ab2453-d53f-4739-8243-42fa29d9f093}</Project>
      <Name>Core.Interface</Name>
    </ProjectReference>  
  </ItemGroup>  
  <Import Project="$(MSBuildBinPath)\Microsoft.CSharp.targets" />  
</Project>
'@
}

Describe "Reference conversion" {
   $csproj = import-csproj $xml
   $refs = get-projectreferences -csproj $csproj
   
   $w = New-Object IO.StringWriter
   $csproj.Save($w)
   $original = $w.ToString()
   $w.Dispose()         

   $packagesdir =  "$psscriptroot\input\packages"
 
   Context "converting reference to nuget and no packages dir specified" {
       $projectname = "Core.Client"
        $projref = $refs | ? { $_.Node.Name -ieq $projectname }
        It "project references to $projectname should be valid" {
            $projref | Should Not BeNullOrEmpty
        }

        It "Should Convert properly" {
            $nugetref = convertto-nuget $projref -packagesRelPath $packagesdir
            $nugetref | Should Not BeNullOrEmpty
            $nugetref.HintPath | Should Not BeNullOrEmpty
            $nugetref.Hintpath.Contains($packagesdir) | Should Be $true        
        }
        #It "Should use global packages dir" {
        #    $nugetref | Should Not BeNullOrEmpty
        #}

        It "Should not modify csproj" {
            $w = New-Object IO.StringWriter
            $csproj.Save($w)
            $csproj.Save("$psscriptroot\input\tmp.csproj")
            $outxml = $w.ToString()
            $w.Dispose()
            $outxml | Should Be $original
        }
   }
}

Describe "Nuget path resolution" {
    $packagesdir =  "$psscriptroot\input\packages"
    Context "When resolving nuget paths" {
        $packages = get-childitem $packagesdir
        $cases = $packages | % { @{ pkgdir = $_.Name -replace "\.([0-9]\.*)+(-.+)*$",""  } }
        
        It "Should resolve proper path for package '<pkgdir>' without version" -TestCases $cases {
            param ($pkgdir)

            $nuget = find-nugetPath $pkgdir -packagesRelPath $packagesdir
            if ($nuget -eq $null) {
                $nuget = find-nugetPath $pkgdir -packagesRelPath $packagesdir                
            }
            $nuget | Should Not BeNullOrEmpty
        }

        $cases = $packages | % { @{ pkgdir = $_.Name  } }        
        It "Should resolve proper path for package '<pkgdir>' with version" -TestCases $cases {
            param ($pkgdir)
            Set-TestInconclusive
            #$nuget = find-nugetPath $pkgdir -packagesRelPath $packagesdir
            #$nuget | Should Not BeNullOrEmpty
        }
        
    }
}