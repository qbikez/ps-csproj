import-module nupkg

$script:ns = 'http://schemas.microsoft.com/developer/msbuild/2003'

$script:types = @"
using System.Xml;
public class Csproj {
    public System.Xml.XmlDocument Xml {get;set;}
    public string Path {get;set;}
    public string FullName { get { return Path; } }
    public string Name {get;set;}
    public string Guid {get;set;}
    
    public override string ToString() {
        return Name;
    }
    
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
    public string ShortName {get;set;}
    public string Type {get;set;}
    public string Path {get;set;}
    public bool? IsValid {get;set;}
    
    public override string ToString() {
        return string.Format("-> {1}{0}", ShortName, IsValid != null ? ((IsValid.Value ? "[+]" : "[-]") + " ") : "");
    }
}
"@


if (-not ([System.Management.Automation.PSTypeName]'Csproj').Type) {
    add-type -TypeDefinition $types -ReferencedAssemblies "System.Xml","System.Xml.ReaderWriter","System.IO","System.Runtime.Extensions"
}


function import-csproj {
    [OutputType([Csproj])]
    param([Parameter(ValueFromPipeline=$true)]$file) 
    $path = $null
    if (test-path $file) { 
        $content = get-content $file
        $path = (get-item $file).FullName    
        $name = [System.IO.Path]::GetFilenameWithoutExtension($file)
    }
    elseif ($file.Contains("<?xml") -or $file.Contains("<Project")) {
        $content = $file.Trim()
    }
    else {
        throw "csproj file not found: '$file'"
    }

    try {
        $xml =[xml]$content
    } catch {
        throw "failed to parse project '$file': $_"
    }
    
     try {
    $guidNode = $xml | get-nodes -nodeName "ProjectGuid"
    $guid = $guidnode.Node.InnerText
     } catch {
         Write-Warning $_
         throw "failed to find ProjectGuid in file '$file': $($_.Exception.Message)"
     }
    $csproj = new-object -type csproj -Property @{ 
        xml = $xml
        path = $path
        name = $name
        guid = $guid
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
param(
    [parameter(ValueFromPipeline=$true)]$nodes,
    [Csproj]$csproj
    ) 
    process {
        $n = $nodes
        if ($nodes.Node) { $n = $nodes.Node }
        $name = get-referenceName $n
        # $n.Name can be hidden by dynamic property from Name attribute/child
        $type = switch($n.get_Name()) {
            "ProjectReference" { "project" }
            "Reference" { "dll" }
            default { "?" }
        }
        $path = $null
        
        #TODO: Reference node may have more than one HintPath! 
        if ($n.HintPath) { $path = $n.HintPath }
        elseif ($n.Include) { $path = $n.Include }
        
        if ($path -is [System.Array]) {
            #hopefully, the last path will be a nuget package
            $path = $path[$path.length -1]
        }
        $isvalid = $null
        $abspath = $path
        
      
        
        if ($abspath -ne $null `
        -and (test-ispathrelative $abspath) `
        -and $csproj -ne $null `
        -and ![string]::IsNullOrEmpty($csproj.fullname))
        {
            try {
            $abspath = join-path (split-path -parent $csproj.fullname) $abspath
            } catch {
                write-error $_.ScriptStackTrace
                throw "failed to find abs path of $csproj ($($csproj.length)): $_"
            }
        }
        if (!(test-ispathrelative $abspath)) {
            $isvalid = test-path $abspath
        }
        
        return new-object -TypeName ReferenceMeta -Property @{ 
            Node = $n
            Name = $name
            ShortName = get-shortname $name 
            Type = $type
            Path = $path
            IsValid = $isvalid
        }
    }
}

function get-nodes([Parameter(ValueFromPipeline=$true)][xml] $xml, $nodeName) {
    $r = Select-Xml -Xml $xml.Project -Namespace @{ d = $ns } -XPath "//d:$nodeName" 
    return $r
}

function get-referencenodes([Parameter(ValueFromPipeline=$true)][xml] $xml, $nodeName, [switch][bool]$noMeta, [Csproj] $csproj) {
    $r = get-nodes $xml $nodename
    if (!$nometa) { 
        $meta = $r | add-metadata -csproj $csproj
    }
    return $meta
}

function get-projectreferences([Parameter(ValueFromPipeline=$true, Mandatory=$true)][csproj] $csproj) {
    return get-referencenodes $csproj.xml "ProjectReference"  -csproj $csproj
}

function get-allexternalreferences([Parameter(ValueFromPipeline=$true, Mandatory=$true)][csproj] $csproj) {
    get-referencenodes $csproj.xml "Reference[d:HintPath]"  -csproj $csproj    
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
        $_.Node.HintPath -match "([\""\\/]|^)packages[/\\]"
    }
    $refs = $refs | % {
        $_.type = "nuget"
        $_
    }
    return $refs
}


function get-systemreferences([Parameter(ValueFromPipeline=$true, Mandatory=$true)][csproj] $csproj) {
    get-referencenodes $csproj.xml "Reference[not(d:HintPath)]" -csproj $csproj    
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


function new-projectReferenceNode([System.Xml.xmldocument]$document) {
 <#
    <ProjectReference Include="..\xxx\xxx.csproj">
      <Project>{89c414d8-0258-4a94-8e45-88b338c15e7a}</Project>
      <Name>xxx</Name>
    </ProjectReference>
 #>
    $projectRef = [System.Xml.XmlElement]$document.CreateNode([System.Xml.XmlNodeType]::Element, "", "ProjectReference", $ns)
    $includeAttr = [System.Xml.XmlAttribute]$document.CreateAttribute("Include")
    
    #$nugetref = [System.Xml.XmlElement]$document.CreateElement("Reference");
    $projectGuid = [System.Xml.XmlElement]$document.CreateNode([System.Xml.XmlNodeType]::Element, "", "Project", $ns)
    $projectName = [System.Xml.XmlElement]$document.CreateNode([System.Xml.XmlNodeType]::Element, "", "Name", $ns)
        
    $null = $projectRef.Attributes.Append($includeAttr)
    $null = $projectRef.AppendChild($projectName)
    $null = $projectRef.AppendChild($projectGuid)

    return $projectRef
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
param ([Parameter(Mandatory=$true)] $csproj, [Parameter(Mandatory=$true)][string] $file)

    ipmo pathutils

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



function convertto-nugetreference { 

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
    
    $nuget = find-nugetPath $projectName $packagesRelPath
    $path = $nuget.Path
    $version = $nuget.LatestVersion
    $framework = $nuget.Framework 

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


function convertto-projectreference { 

[OutputType([ReferenceMeta])]    
param(
    [Parameter(Mandatory=$true)]
    [ReferenceMeta] $ref, 
    [Parameter(Mandatory=$true)]
    [string ]$targetProject
) 
    $node = get-asnode $ref
 
 <#
    <ProjectReference Include="..\xxx\xxx.csproj">
      <Project>{89c414d8-0258-4a94-8e45-88b338c15e7a}</Project>
      <Name>xxx</Name>
    </ProjectReference>
 #>
 # TODO: handle relative path
    $targetcsproj = import-csproj $targetProject
    $guidNode = $targetcsproj.xml | get-nodes -nodeName "ProjectGuid"
    $guid = $guidnode.Node.InnerText
    $projectRef = new-projectReferenceNode $node.OwnerDocument
    $projectRef.Include = $targetProject
    $projectRef.Name = [System.IO.Path]::GetFilenameWithoutExtension($targetProject)
    $projectRef.Project = $guid
    
     

    $meta = $projectRef | add-metadata
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
    
    write-verbose "replacing:"
    write-verbose "`r`n$($originalref.Node.OuterXml)"
    write-verbose "with:"
    write-verbose "`r`n$($newref.Node.OuterXml)"
        
    if ($csproj.path -ne $null -and $newref.Type -ne "project") {
        $dir = split-path -Parent $csproj.path      
        $pkgs = get-packagesconfig (Join-Path $dir "packages.config") -createifnotexists
        add-packagetoconfig -packagesconfig $pkgs -package $newref.Name -version $newref.Version -ifnotexists
        #make sure paths are relative
        $newref.Node.HintPath = (Get-RelativePath $dir $newref.Node.HintPath)
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

new-alias replace-reference convert-reference -Force
new-alias convertto-nuget convertto-nugetreference -Force