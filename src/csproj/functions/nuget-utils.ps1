
function get-shortName($package) {
    $m = $package -match "(?<shortname>.*?)(,(?<specificversion>.+)){0,1}$"
    return $Matches["shortname"]
}


<# this is duplicated from nupkg module #>
function  find-packagesdir  {
    [CmdletBinding()]
    param ($path, [switch][bool]$all)

    if ($path -eq $null) {
        $path = "."
    }
    $result = @()
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
                        $result += @($packagesdir)
                        if (!$all) { return $result } 
                    }
                    else { 
                        $result += @((get-item (join-path $dir $packagesdir)).fullname)
                        if (!$all) { return $result}  
                    }
                }
            }
            if ((test-path "$dir/packages") -or (Test-Path "$dir/packages")) {
                 write-verbose "found 'packages' in dir $dir"
                 $result += @("$dir/packages")
                 if (!$all) { return $result }  
            }
            if ((test-path "$dir/dnx-packages") -or (Test-Path "$dir/dnx-packages")) {
                 write-verbose "found 'dnx-packages' in dir $dir"
                 $result += @("$dir/dnx-packages")
                 if (!$all) { return $result }  
            }
            $dir = split-path -Parent $dir
            if ($result.Count -gt 0) { return $result }
        }
        return $null
}
