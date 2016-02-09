import-module Pester
. $PSScriptRoot\includes.ps1

$inputdir = "$psscriptroot\input"

Describe "parsing minimal xml" {
$xml = @'
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
   }
}

Describe "Parsing references" {
    Context "When parsing csproj" {
        
        $dir = "$inputdir\Platform\src\sample.project1"
        $csproj = import-csproj "$dir\sample.project1.csproj"
        It "should return a valid object" {
            $csproj | Should Not BeNullOrEmpty
        }

        It "should cointain xxx references" {
            $refs = get-projectreferences $csproj
        
            log-info 
            log-info "Project references:"

            $refs | % {
                log-info $_.Node.OuterXml
            }      
            
            $refs.Count | Should Be 3   

        }
    }
}