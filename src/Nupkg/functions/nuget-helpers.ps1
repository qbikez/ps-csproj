
function  find-packagesdir  {
    [CmdletBinding()]
    param ($path)

    if ($path -eq $null) {
        $path = "."
    }
    
    if (!(get-item $path).PsIsContainer) {
            $dir = split-path -Parent (get-item $path).fullname
        }
        else {
            $dir = (get-item $path).fullname
        }        
        while(![string]::IsNullOrEmpty($dir)) {
            if (test-path "$dir/nuget.config") {
                $nugetcfg = [xml](get-content "$dir/nuget.config" | out-string)
                write-verbose "found nuget.config in dir $dir"
                $node = ($nugetcfg | select-xml -XPath "//configuration/config/add[@key='repositoryPath']")
                if ($node -ne $null) {
                    $packagesdir = $node.node.value
                    if ([System.IO.Path]::IsPathRooted($packagesdir)) { 
                        return $packagesdir 
                    }
                    else { 
                        return (get-item (join-path $dir $packagesdir)).fullname 
                    }
                }
            }
            if ((test-path "$dir/packages") -or (Test-Path "$dir/packages")) {
                 write-verbose "found 'packages' in dir $dir"
                 return "$dir/packages"
            }
            $dir = split-path -Parent $dir
        }
        return $null
}

