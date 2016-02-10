import-module Pester
. $PSScriptRoot\includes.ps1

$inputdir = "$psscriptroot\input"

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
    <ProjectReference Include="..\..\Core\NowaEra.Core.Boundaries.Client\NowaEra.Core.Boundaries.Client.csproj">
      <Project>{1ed821b1-89d1-4383-9e3a-ad7161b6640a}</Project>
      <Name>NowaEra.Core.Boundaries.Client</Name>
    </ProjectReference>
    <ProjectReference Include="..\..\Core\NowaEra.Core.Boundaries\NowaEra.Core.Boundaries.csproj">
      <Project>{32ab2453-d53f-4739-8243-42fa29d9f093}</Project>
      <Name>NowaEra.Core.Boundaries</Name>
    </ProjectReference>  
  </ItemGroup>  
  <Import Project="$(MSBuildBinPath)\Microsoft.CSharp.targets" />  
</Project>
'@
}

Describe "Basic reference parsing" {
   
   Context "when parsing csproj string" {
        $csproj = import-csproj $xml
         It "should return a valid object" {
            $csproj | Should Not BeNullOrEmpty
        }
        It "should have 2 package references" {
            $refs = get-nugetreferences $csproj
            $refs.Count | Should Be 2
            $refs | ? { $_.Node.INclude -ieq "Castle.Core" } | Should Not BeNullOrEmpty
            $refs | ? { $_.Node.INclude -imatch "^Common.Configuration.log4net" } | Should Not BeNullOrEmpty
        }
        It "should have 2 project references" {
            $refs = get-projectreferences $csproj
            $refs.Count | Should Be 2
            $refs | ? { $_.Node.Name -ieq "NowaEra.Core.Boundaries.Client" } | Should Not BeNullOrEmpty
            $refs | ? { $_.Node.Name -ieq "NowaEra.Core.Boundaries" } | Should Not BeNullOrEmpty            
        }
        It "reference should contain generated meta" {
            $refs = get-projectreferences $csproj
            
            $refs | % { $_.Name | Should Not BeNullOrEmpty }
            $refs | % { $_.Version | Should Not BeNullOrEmpty }
            
            $refs = get-nugetreferences $csproj
            
            $refs | % { $_.Name | Should Not BeNullOrEmpty }
            $refs | % { $_.Version | Should Not BeNullOrEmpty }

            $refs | % { $_.Name | Should Be $_.Node.Name }
        }
   }
}


Describe "Reference manipulation" {
    $csproj = import-csproj $xml
    Context "When converting project reference to nuget" {
        $refs = get-projectreferences -csproj $csproj
        $projref = $refs[0]
        $nuget = convertto-nuget -ref $projref "packages" 


        It "Project reference should become nuget reference" {
            
        }
        It "Nuget reference shuld point to a valid file" {
        }
        It "packages.config should contain nuget reference" {
        }
        It "Should restore properly" {
        }
        It "Should Still Compile" {
        }
    }
}

