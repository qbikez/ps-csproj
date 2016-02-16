function add-packagetoconfig {
param([Parameter(Mandatory=$true)]$package, $packagesconfig) 
    
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