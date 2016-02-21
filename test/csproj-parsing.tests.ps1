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
            write-host $refs
            $refs | ? { $_.Node.Name -ieq "Core.Client" } | Should Not BeNullOrEmpty
            $refs | ? { $_.Node.Name -ieq "Core.Interface" } | Should Not BeNullOrEmpty            
        }

        $refs = get-allreferences $csproj
        $cases = $refs | % { @{ Name = $_.Name; Node = $_.Node; Ref = $_ }}
        
        It "reference should contain generated meta Name <Name>" -TestCases $cases {
            param ($ref) 
            $ref.Name | Should Not BeNullOrEmpty 
            $ref.Name | Should Match "^[^.,\s]+(.[^.,\s]+)+($|,)"
            #$ref.Name | Should Be $ref.Node.Name 
        }

        $grouped = $refs | Group-Object "Name"
        It "references should be distinct"  {
           $grouped | % { $_.Count | Should Be 1 }
        }
   }
}


Describe "Reference node manipulation" {
    $csproj = import-csproj $xml
    Context "When converting project reference to nuget" {
        $refs = get-projectreferences -csproj $csproj
        It "Cannot convert when nuget is missing" {
            $projref = $refs | ? { $_.Name -eq  "Core.Client" }
            if (test-path "$inputdir\packages\Core.Client.*") {
                remove-item "$inputdir\packages\Core.Client.*" -Recurse
            } 
            { convertto-nuget -ref $projref "$inputdir\packages" } | Should Throw 
        }

            $projref = $refs | ? { $_.Name -eq  "Core.Client" }
            if (!(test-path "$inputdir\packages\Core.Client.*")) {
                $null = new-item -type directory "$inputdir\packages\Core.Client.1.0.1\lib"
                $null = new-item -type file "$inputdir\packages\Core.Client.1.0.1\lib\Core.Client.dll"
            } 
        It "Project reference should convert to nuget reference" {
            $converted = convertto-nuget -ref $projref "$inputdir\packages" 
            $converted.Node.Name | Should Be "Reference"
        }
        It "Nuget reference shuld point to a valid file" {
            $converted = convertto-nuget -ref $projref "$inputdir\packages" 
            $converted.Node.HintPath | Should Be "$inputdir\packages\Core.Client.1.0.1\lib\Core.Client.dll"
        }
    }
}

