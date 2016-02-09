$ns = 'http://schemas.microsoft.com/developer/msbuild/2003'

. "$PSScriptRoot\nuget-utils.ps1"

function import-csproj([Parameter(ValueFromPipeline=$true)]$file) {
    if (test-path $file) { 
        $content = get-content $file
    }
    elseif ($file.Contains("<?xml") -or $file.Contains("<Project")) {
        $content = $file
    }
    else {
        throw "file not found: '$file'"
    }

    $csproj = [xml]$content

    return $csproj
}
function get-nodes([Parameter(ValueFromPipeline=$true)][xml] $csproj, $nodeName) {
    return Select-Xml -Xml $csproj.Project -Namespace @{ d = $ns } -XPath "//d:$nodeName"     
}

function get-projectreferences([Parameter(ValueFromPipeline=$true)][xml] $csproj) {
    return get-nodes $csproj "ProjectReference"
}

function get-externalreferences([Parameter(ValueFromPipeline=$true)][xml] $csproj) {
    return Select-Xml -Xml $csproj.Project -Namespace @{ d = $ns } -XPath "//d:Reference[d:HintPath]"     

}

function get-nugetreferences([Parameter(ValueFromPipeline=$true)][xml] $csproj) {
    $refs = get-externalreferences $csproj
    $refs = $refs | ? {
        $_.Node.HintPath -match "[""\\/]packages[/\\]"
    }
    return $refs
}


function get-systemreferences([Parameter(ValueFromPipeline=$true)][xml] $csproj) {
    return Select-Xml -Xml $csproj.Project -Namespace @{ d = $ns } -XPath "//d:Reference[not(d:HintPath)]"     

}

function remove-node([Parameter(ValueFromPipeline=$true)]$node) {    
    $node.ParentNode.RemoveChild($node)
}

function new-referenceNode([System.Xml.xmldocument]$document) {

    $nugetref = [System.Xml.XmlElement]$document.CreateNode([System.Xml.XmlNodeType]::Element, "", "Reference", $ns);
    #$nugetref = [System.Xml.XmlElement]$document.CreateElement("Reference");
    $includeAttr = [System.Xml.XmlAttribute]$document.CreateAttribute("Include");
    $hint = [System.Xml.XmlElement]$document.CreateElement("HintPath");
    $null = $nugetref.Attributes.Append($includeAttr);
    $null = $nugetref.AppendChild($hint);

    return $nugetref
}


function add-projectItem {
[CmdletBinding()]
param ($csproj, $file)

    ipmo deployment

    if ($csproj -is [string]) {
        $csprojPath = $csproj
        $document = load-csproj $csprojPath
    }
    else {
        $document = $csproj
    }

    if ($csprojPath -ne $null) {
        $file = Get-RelativePath -Dir (split-path -Parent $csprojPath) $file
    }
    <# <ItemGroup>
    <None Include="NowaEra.XPlatform.Sync.Client.nuspec">
      <SubType>Designer</SubType>
    </None>
    <None Include="packages.config">
      <SubType>Designer</SubType>
    </None>
  </ItemGroup>
    #>
    $itemgroup = [System.Xml.XmlElement]$document.CreateNode([System.Xml.XmlNodeType]::Element, "", "ItemGroup", $ns);
    $none = [System.Xml.XmlElement]$document.CreateNode([System.Xml.XmlNodeType]::Element, "", "None", $ns);
    $null = $itemgroup.AppendChild($none)
    $includeAttr = [System.Xml.XmlAttribute]$document.CreateAttribute("Include");
    $null = $none.Attributes.Append($includeAttr);

    $none.Include = "$file"
    
    write-verbose "adding item '$file': $($itemgroup.OuterXml)"

    $other = get-nodes -csproj $document -nodeName "ItemGroup"
    if ($other.Count -gt 0) {
        $last = ([System.Xml.XmlNode]$other[$other.Count - 1].Node)
        $null = $last.ParentNode.InsertAfter($itemgroup, $last)
    } else {
        $null = $document.AppendChild($itemgroup)
    }

    if ($csprojPath -ne $null) {
        write-verbose "saving project '$csprojPath'" -verbref $VerbosePreference
        $document.Save($csprojPath)
    }
}



function convertto-nuget($ref, $packagesRelPath) {
    $projectPath = $ref.Include
    $projectId = $ref.Project
    $projectName = $ref.Name

    $path = find-nugetPath $projectName $packagesRelPath

    if ($path -eq $null) {
        throw "package '$projectName' not found in packages dir '$packagesRelPath'"
    }

    $nugetref = create-referenceNode $ref.OwnerDocument
    $nugetref.Include = $projectName  

    $nugetref.hintpath = $path
    $null = $ref.parentNode.AppendChild($nugetref)
}

function get-project($name, [switch][bool]$all) {
    $projs = gci -Filter "*.csproj"
    if ($name -ne $null) {
        $projs = $projs | ? { $_.Name -eq "$name.csproj" }
    }

    $projs = $projs | % {
        new-object -type pscustomobject -Property @{
            FullName = $_.FullName
            File = $_
            Name = $_.Name
        }
    }

    return $projs
}

