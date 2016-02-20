function add-packagetoconfig {
param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]$packagesconfig,
    [Parameter(Mandatory=$true)][string]$package, 
<<<<<<< HEAD
    [Parameter(Mandatory=$true)][string]$version,
    [switch][bool] $ifnotexists
) 
    $existing = $packagesconfig.packages | ? { $_.Id -eq $package } 
    if ($existing -ne $null) {
        if ($ifnotexists) { return }
        else { 
            throw "Packages.config already contains reference to package $package : $($existing | out-string)" 
        }
    } 
=======
    [Parameter(Mandatory=$true)][string]$version
) 
>>>>>>> 1dc1c60c9c4ddee2c774bb4ca33c79ecded806b3
    $node = new-packageNode -document $packagesconfig.xml
    $node.id = $package
    $node.version = $version
    $null = $packagesconfig.xml.packages.AppendChild($node) 
    
    $packagesconfig.packages = $packagesconfig.xml.packages.package
}

function remove-packagefromconfig {
param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]$packagesconfig,
    [Parameter(Mandatory=$true)][string]$package
    ) 
    $existing = $packagesconfig.packages | ? { $_.Id -eq $package } 
    if ($existing -ne $null) {
        $packagesconfig.xml.packages
        $xmlel = ([System.Xml.XmlElement]$packagesconfig.xml.packages)
        $null = $xmlel.RemoveChild($existing)
        $packagesconfig.packages = $packagesconfig.xml.packages.package
    }
    else {
        throw "package $package not found in packages.config"
    }
}

function get-packagesconfig {
param($packagesconfig)
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

