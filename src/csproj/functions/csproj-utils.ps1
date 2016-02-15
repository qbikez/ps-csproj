$ns = 'http://schemas.microsoft.com/developer/msbuild/2003'

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

function get-referenceName($node) {
    if ($node.HasAttribute("Name")) {
        return $node.GetAttribute("Name")
    }
    if ($node.GetElementsByTagName("Name") -ne $null) {
        return $node.Name
    }
    
    if ($node.Include -ne $null) {
        return $node.Include
    }
}

function add-metadata {
param([parameter(ValueFromPipeline=$true)]$nodes) 
    process {
        return new-object -TypeName pscustomobject -Property @{ 
            Node = $nodes.Node
            Name = get-referenceName $nodes.Node
        }
    }
}

function get-nodes([Parameter(ValueFromPipeline=$true)][xml] $csproj, $nodeName) {
    $xml = Select-Xml -Xml $csproj.Project -Namespace @{ d = $ns } -XPath "//d:$nodeName" 
    $meta = $xml | add-metadata
    return $meta
}

function get-projectreferences([Parameter(ValueFromPipeline=$true, Mandatory=$true)][xml] $csproj) {
    return get-nodes $csproj "ProjectReference"
}

function get-allexternalreferences([Parameter(ValueFromPipeline=$true, Mandatory=$true)][xml] $csproj) {
    get-nodes $csproj "Reference[d:HintPath]"     

}


function get-externalreferences([Parameter(ValueFromPipeline=$true, Mandatory=$true)][xml] $csproj) {
    $refs = get-allexternalreferences $csproj
    $refs = $refs | ? {
        $_.Node.HintPath -notmatch "[""\\/]packages[/\\]"
    }
    return $refs
}


function get-nugetreferences([Parameter(ValueFromPipeline=$true, Mandatory=$true)][xml] $csproj) {
    $refs = get-allexternalreferences $csproj
    $refs = $refs | ? {
        $_.Node.HintPath -match "[""\\/]packages[/\\]"
    }
    return $refs
}


function get-systemreferences([Parameter(ValueFromPipeline=$true, Mandatory=$true)][xml] $csproj) {
    get-nodes $csproj "Reference[not(d:HintPath)]"     
}


function get-allreferences([Parameter(ValueFromPipeline=$true, Mandatory=$true)][xml] $csproj) {
    $refs = @()
    $refs += get-systemreferences $csproj
    $refs += get-nugetreferences $csproj
    $refs += get-externalreferences $csproj

    return $refs
}

function remove-node([Parameter(ValueFromPipeline=$true)]$node) {    
    $node.ParentNode.RemoveChild($node)
}

function new-referenceNode([System.Xml.xmldocument]$document) {

    $nugetref = [System.Xml.XmlElement]$document.CreateNode([System.Xml.XmlNodeType]::Element, "", "Reference", $ns);
    #$nugetref = [System.Xml.XmlElement]$document.CreateElement("Reference");
    $includeAttr = [System.Xml.XmlAttribute]$document.CreateAttribute("Include");
    $hint = [System.Xml.XmlElement]$document.CreateElement("HintPath");
    $hint.InnerText = "hint"
    $null = $nugetref.Attributes.Append($includeAttr);
    $null = $nugetref.AppendChild($hint);

    return $nugetref
}


function add-projectItem {
[CmdletBinding()]
param ([Parameter(Mandatory=$true)] $csproj, [Parameter(Mandatory=$true)] $file)

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



function convertto-nuget(
    [Parameter(Mandatory=$true)]
    $ref, 
    [Parameter(Mandatory=$true)]
    $packagesRelPath
) 
{
    if ($ref.Node -ne $null) {
        $ref = $ref.Node
    }
    $projectPath = $ref.Include
    $projectId = $ref.Project
    $projectName = $ref.Name

    $path = find-nugetPath $projectName $packagesRelPath

    if ($path -eq $null) {
        throw "package '$projectName' not found in packages dir '$packagesRelPath'"
    }

    $nugetref = new-referenceNode $ref.OwnerDocument
    $nugetref.Include = $projectName  

    $hintNode = $nugetref.ChildNodes | ? { $_.Name -eq "HintPath" }
    $hintNode.InnerText = $path
    #$nugetref.hintpath = $path

    return $nugetref
}

function replace-reference ($csproj, $originalref, $newref) {

    $null = $originalref.parentNode.AppendChild($newref)
    $originalref.parentNode.RemoveChild($originalref)
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

