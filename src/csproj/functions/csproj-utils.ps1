$script:ns = 'http://schemas.microsoft.com/developer/msbuild/2003'

$script:types = @"
using System.Xml;
public class Csproj {
    public System.Xml.XmlDocument Xml {get;set;}
    public string Path {get;set;}
    
    public void Save() {
        this.Xml.Save(this.Path);
    }
    public void Save(string path) {
        this.Xml.Save(path);
    }
    public void Save(System.IO.TextWriter w) {
        this.Xml.Save(w);
    }
}

public class ReferenceMeta {
    public System.Xml.XmlElement Node {get;set;}
    public string Name {get;set;}
    public string Version {get;set;}
}
"@

add-type -TypeDefinition $types -ReferencedAssemblies "System.Xml"


function import-csproj {
    [OutputType([Csproj])]
    param([Parameter(ValueFromPipeline=$true)]$file) 
    $path = $null
    if (test-path $file) { 
        $content = get-content $file
        $path = (get-item $file).FullName    
    }
    elseif ($file.Contains("<?xml") -or $file.Contains("<Project")) {
        $content = $file
    }
    else {
        throw "file not found: '$file'"
    }

    $csproj = new-object -type csproj -Property @{ 
        xml = [xml]$content
        path = $path
    }

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
        $n = $nodes
        if ($nodes.Node) { $n = $nodes.Node }
        return new-object -TypeName ReferenceMeta -Property @{ 
            Node = $n
            Name = get-referenceName $n
        }
    }
}

function get-nodes([Parameter(ValueFromPipeline=$true)][xml] $xml, $nodeName) {
    $r = Select-Xml -Xml $xml.Project -Namespace @{ d = $ns } -XPath "//d:$nodeName" 
    $meta = $r | add-metadata
    return $meta
}

function get-projectreferences([Parameter(ValueFromPipeline=$true, Mandatory=$true)][csproj] $csproj) {
    return get-nodes $csproj.xml "ProjectReference"
}

function get-allexternalreferences([Parameter(ValueFromPipeline=$true, Mandatory=$true)][csproj] $csproj) {
    get-nodes $csproj.xml "Reference[d:HintPath]"     
}


function get-externalreferences([Parameter(ValueFromPipeline=$true, Mandatory=$true)][Csproj] $csproj) {
    $refs = get-allexternalreferences $csproj
    $refs = $refs | ? {
        $_.Node.HintPath -notmatch "[""\\/]packages[/\\]"
    }
    return $refs
}


function get-nugetreferences([Parameter(ValueFromPipeline=$true, Mandatory=$true)][csproj] $csproj) {
    $refs = get-allexternalreferences $csproj
    $refs = $refs | ? {
        $_.Node.HintPath -match "[""\\/]packages[/\\]"
    }
    return $refs
}


function get-systemreferences([Parameter(ValueFromPipeline=$true, Mandatory=$true)][csproj] $csproj) {
    get-nodes $csproj.xml "Reference[not(d:HintPath)]"     
}


function get-allreferences([Parameter(ValueFromPipeline=$true, Mandatory=$true)][csproj] $csproj) {
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

    $nugetref = [System.Xml.XmlElement]$document.CreateNode([System.Xml.XmlNodeType]::Element, "", "Reference", $ns)
    #$nugetref = [System.Xml.XmlElement]$document.CreateElement("Reference");
    $includeAttr = [System.Xml.XmlAttribute]$document.CreateAttribute("Include")
    $hint = [System.Xml.XmlElement]$document.CreateNode([System.Xml.XmlNodeType]::Element, "", "HintPath", $ns)
    $hint.InnerText = "hint"
    $null = $nugetref.Attributes.Append($includeAttr)
    $null = $nugetref.AppendChild($hint)

    return $nugetref
}


function add-projectItem {
[CmdletBinding()]
param ([Parameter(Mandatory=$true)] $csproj, [Parameter(Mandatory=$true)] $file)

    ipmo deployment

    if ($csproj -is [string]) {
        $csprojPath = $csproj
        $document = (import-csproj $csprojPath).xml
    }
    else {
        $document = $csproj.xml
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

    $other = get-nodes $document -nodeName "ItemGroup"
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



function convertto-nuget { 

[OutputType([ReferenceMeta])]    
param(
    [Parameter(Mandatory=$true)]
    [ReferenceMeta] $ref, 
    [Parameter(Mandatory=$true)]
    [string ]$packagesRelPath
) 
    $node = get-asnode $ref
    $projectPath = $node.Include
    $projectId = $node.Project
    $projectName = $node.Name

    $path,$version,$framework = find-nugetPath $projectName $packagesRelPath

    if ($path -eq $null) {
        throw "package '$projectName' not found in packages dir '$packagesRelPath'"
    }

    $nugetref = new-referenceNode $node.OwnerDocument
    $nugetref.Include = $projectName  

    $hintNode = $nugetref.ChildNodes | ? { $_.Name -eq "HintPath" }
    $hintNode.InnerText = $path
    #$nugetref.hintpath = $path

    $meta = $nugetref | add-metadata
    $meta.Version = $version
    return $meta
}

function convert-reference { 
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)][csproj] $csproj, 
    [Parameter(Mandatory=$true)][referenceMeta] $originalref, 
    [Parameter(Mandatory=$true)][referenceMeta] $newref
    ) 
    #$originalref = $originalref | get-asnode
    #$newref = $newref | get-asnode
    $null = $originalref.Node.parentNode.AppendChild($newref.Node)
    $null = $originalref.Node.parentNode.RemoveChild($originalref.Node)
    
    if ($csproj.path -ne $null) {
        $dir = split-path -Parent $csproj.path      
        $pkgs = get-packagesconfig (Join-Path $dir "packages.config") -createifnotexists
        add-packagetoconfig -packagesconfig $pkgs -package $newref.Name -version $newref.Version -ifnotexists
        $pkgs.xml.Save( (Join-Path $dir "packages.config") ) 
    }
    else {
        write-warning "passed csproj path==null. Cannot edit packages.config"
    }
}

function get-asnode {
    param([Parameter(Mandatory=$true, ValueFromPipeline=$true)]$ref)
    
    if ($ref -is [System.Xml.XmlNode]) {return $ref }
    elseif ($ref.Node -ne $null) { return $ref.Node }
    else { throw "$ref is not a node and has no 'Node' property"}
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

new-alias replace-reference convert-reference