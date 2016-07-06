
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




function find-nugetdll {
    param (
        [Parameter(Mandatory=$true)] $name, 
        [Parameter(Mandatory=$true)] $path
    )
     
    $dll = join-path $path "$name.dll"
    if (test-path $dll) { return $dll } 
    $exe = join-path $path "$name.exe"
    if (test-path $exe) { return $exe }
    
    $dlls = @(gci $path -Filter "*.dll")
    if ($dlls.Length -eq 1) {
        return join-path $path $dlls[0].Name
    }

    $execs = @(gci $path -Filter "*.exe")
    if ($execs.Length -eq 1) {
        return join-path $path $execs[0].Name
    }
    return $null
}


function get-nugetname {
    param($name)
    if ($name -match "(?<name>.*?)\.(?<version>[0-9]+(\.[0-9]+)*(-.*){0,1})") {
        return $Matches["name"]    
    }
    else {
        return $name
    }
}

function find-nugetPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] $name, 
        [Parameter(Mandatory=$true)] $packagesRelPath, 
        [Parameter(Mandatory=$false)] $frameworkHint,
        [Parameter(Mandatory=$false)] $versionHint
    ) 
    $name = get-nugetname $name
    # get latest package version
    # TODO: handle a case when project $name contains version
    $versions = Get-PackageFolderVersions -packageName $name -packagesDir $packagesRelPath
    if ($versions.count -gt 0) {
        $latest = Get-LatestPackageVersion -packageVersions $versions
         if ($versionHint -ne $null) {
            $latest = $versionHint
        }
        $packageDir = join-path $packagesRelPath "$name.$latest"
    }
    if ($versions.count -eq 0) {
        $latest = $null
        $packageDir = join-path $packagesRelPath "$name"
        if (!(test-path ($packageDir))) {
            return $null 
        }        
    }
    
    # get correct framework and dll
    # check lib\*
    $libpath = join-path $packageDir "lib"
    if (!(test-path $libpath)) { 
        $toolspath = join-path $packageDir "tools"
        if ((test-path $toolspath)) { return $toolspath }
        else {return $null}
    }

    $dll = find-nugetdll $name $libpath
    $path = $null
    $framework = ""
    if ($dll -ne $null) { 
        $path = $dll
    }
    else {
        $frameworks = @(gci $libpath)
        $frameworks = $frameworks | sort-frameworks -frameworkhint $frameworkHint 
        foreach($f in $frameworks) {
            $p = join-path $libpath $f.Name
            $dll = find-nugetdll $name $p
            if ($dll -ne $null) { 
                $path =  $dll
                $framework = $f
                break
            }
        }
    }
    # check lib\frameworkname\*
    return @{
        Path =$path
        LatestVersion=$latest
        Framework=$framework
        PackageDir = $packageDir
    }
}


function get-nugettoolspath {
    [CmdletBinding()]
    param ($packagesdir = $null) 
    if ($packagesdir -eq $null) {
        $packagesdir = find-packagesdir
    }
    write-verbose "looking for 'tools' in packages folder '$packagesDir'"
    $tools = Get-ChildItem $packagesdir -Recurse -Filter "tools"
    return $tools | ? { $_.psiscontainer } | % { $_.FullName }
}

function get-shortName($package) {
    $m = $package -match "(?<shortname>.*?)(,(?<specificversion>.+)){0,1}$"
    return $Matches["shortname"]
}

function split-packagename($package) {
     if ($package -match "[\\/]" ) {
        $package = split-path $package -leaf    
    }
    if ($package -match ".nupkg$" ) {
        $package = $package -replace ".nupkg$",""
    }
    
    $m = $package -match "(?<name>.*?)\.(?<fullversion>(?<version>[0-9]+(\.[0-9]+)*)+(?<suffix>-.*){0,1})$"
    return $Matches
}

function split-packageVersion($version) {
    $m = $version -match "(?<version>[0-9]+(\.[0-9]+)*)+(?<suffix>-.*){0,1}$"
    return $matches
}

function get-packageName($package) {
   $m = split-packagename $package
   return $m["name"]
}


function get-packageversion($package) {
   $m = split-packagename $package
   return $m["fullversion"]
}
