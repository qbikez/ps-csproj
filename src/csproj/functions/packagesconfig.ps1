function add-packagetoconfig {
param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]$packagesconfig,
    [Parameter(Mandatory=$true)][string]$package, 
    [Parameter(Mandatory=$true)][string]$version
) 
    $node = new-packageNode -document $packagesconfig.xml
    $node.id = $package
    $node.version = $version
    $null = $packagesconfig.xml.packages.AppendChild($node) 
    
    $packagesconfig.packages = $packagesconfig.xml.packages.package

}

function remove-packagefromconfig {
param([Parameter(Mandatory=$true)]$package, $packagesconfig) 
    
}

function get-packagesconfig {
param($packagesconfig)

    $xml
    if ($packagesconfig.startswith('<?xml')) {
        $xml = [xml]$packagesconfig
    }
    elseif (test-path $packagesconfig) {
        $c = get-content $packagesconfig | Out-String
        $xml = [xml]$c
    } 
    
    $obj = new-object -type pscustomobject -Property @{ packages = $xml.packages.package; xml = $xml } 
    return $obj
}


function new-packageNode([Parameter(Mandatory=$true, ValueFromPipeline=$true)][System.Xml.xmldocument]$document) {

    $package = [System.Xml.XmlElement]$document.CreateElement("package")
    $null = $package.Attributes.Append([System.Xml.XmlAttribute]$document.CreateAttribute("id"))
    $null = $package.Attributes.Append($document.CreateAttribute("targetFramework"))
    $null = $package.Attributes.Append($document.CreateAttribute("version"))

    return $package
}

