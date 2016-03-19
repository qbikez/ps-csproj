ipmo process
ipmo assemblymeta
$root = "."
if (![string]::IsNullOrEmpty($PSScriptRoot)) {
    $root = $PSScriptRoot
}
#if ($MyInvocation.MyCommand.Definition -ne $null) {
#    $root = $MyInvocation.MyCommand.Definition
#}
$helpersPath = $root
@("choco-utils.ps1", "internal.ps1") |
    % { 
        $p = Resolve-Path "$root/functions/$_"
        . $p.ProviderPath
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
        [Parameter(Mandatory=$false)] $frameworkHint
    ) 
    $name = get-nugetname $name
    # get latest package version
    # TODO: handle a case when project $name contains version
    $versions = Get-PackageFolderVersions -packageName $name -packagesDir $packagesRelPath
    if ($versions.count -eq 0) { return $null }
    $latest = Get-LatestPackageVersion -packageVersions $versions
    $packageDir = join-path $packagesRelPath "$name.$latest"
    
    # get correct framework and dll
    # check lib\*
    $libpath = join-path $packageDir "lib"
    if (!(test-path $libpath)) { return $null }

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
    return $path,$latest,$framework 
}


function get-nugettoolspath($packagesdir = "packages") {
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

function new-nuspec($projectPath = ".") {
    pushd
    try {
        if (!(test-path $projectpath)) { throw "file '$projectPath' not found"}
        if ((get-item $projectpath).psiscontainer) {
            $dir = $projectpath
            $projects = @(get-childitem $dir -filter "*.csproj")
            if ($projects.Length -gt 1) {
                throw "more than one csproj file found in dir '$projectPath'"
            } 
            if ($projects.Length -lt 1) {
                throw "no csproj file found in dir '$projectPath'"
            }
            $projectpath = $projects[0].fullname
        }
        $dir = split-path $projectpath -parent
        $csproj = split-path $projectpath -leaf
        cd $dir
        nuget spec $csproj
    } finally {
        popd
    }
}

function Get-InstalledNugets($packagesdir) {
    $subdirs = get-childitem $packagesdir -Directory
    $result = @()
    foreach($s in $subdirs) {
        $name = get-packageName $s
        $version = get-packageversion $s
        
        if ($name -ne $null -and $version -ne $null) {
            $result += new-object -type pscustomobject -Property @{ 
                Name = $name; Version = $version 
            }
        }
    }
    
    return $result
}

function Get-AvailableNugets ($source) {
    $l = nuget list -source $source
    $l = $l | % {
        $s = $_.split(" ")
         new-object -type pscustomobject -Property @{ 
                Name = $s[0]; Version = $s[1] 
            }
    }
    return $l
}


function invoke-nugetpush {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param($file = $null, 
    [Parameter(Mandatory=$false)]$source,
    [Parameter(Mandatory=$false)]$apikey,
    [switch][bool] $Build,
    [switch][bool] $NoProjectReferences) 
    
    if ($file -eq $null -or !($file.EndsWith(".nupkg"))){
        $nupkg = invoke-nugetpack $file -Build:$build -NoProjectReferences:$NoProjectReferences
    } else {
        $nupkg = $file
    }
    Write-Host "pushing package $nupkg to $source"
    $p = @(
        $nupkg
    )
    if ($source -ne $null) {
        $p += "-source",$source
    }
    if ($apikey -ne $null) {
        $p += "-apikey",$apikey
    }
    if ($PSCmdlet.ShouldProcess("pushing package $p")) {
        $o = nuget push $p | % { write-indented 4 "$_"; $_ } 
        if ($lastexitcode -ne 0) {
            throw "nuget command failed! `r`n$($o | out-string)"
        }
    }
}

function invoke-nugetpack {
    [CmdletBinding()]
    param($nuspecOrCsproj = $null,
    [switch][bool] $Build,
    [switch][bool] $NoProjectReferences) 
    
    if ($nuspecorcsproj -eq $null) {
        $csprojs = @(gci . -filter "*.csproj")
        if ($csprojs.length -eq 1) {
            $nuspecorcsproj = $csprojs[0].Name
        }
    }
    if ($nuspecorcsproj -eq $null) {
        $csprojs = @(gci . -filter "*.nuspec")
        if ($csprojs.length -eq 1) {
            $nuspecorcsproj = $csprojs[0].Name
        }
    }
    
    if ($Build) {
        $newver = update-buildversion (split-path -Parent $nuspecorcsproj)
        write-host "building project"
        $o = msbuild $nuspecorcsproj | % { write-indented 4 "$_"; $_ }
         if ($lastexitcode -ne 0) {
           throw "build failed! `r`n$($o | out-string)"
        }
    }
    
    $a = @(
        "$nuspecorcsproj"
    ) 
    if (!$noprojectreferences) {
        $a += "-IncludeReferencedProjects"
    }
    write-host "packing nuget $nuspecorcsproj"
    write-host "nuget pack $a"
    $o = nuget pack $a | % { write-indented 4 "$_"; $_ } 
    if ($lastexitcode -ne 0) {
        throw "nuget command failed! `r`n$($o | out-string)"
    } else {
        $success = $o | % {
            if ($_ -match "Successfully created package '(.*)'") {
                return $matches[1]
            }
        }
        return $success
    }
    
}


function update-nugetmeta {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param($path = ".", $description = $null, [Alias("company")]$author = $null, $version = $null)
    
    write-verbose "generating nuget meta"
    $v = get-assemblymeta "Description" $path
    if ([string]::isnullorempty($v) -or $description -ne $null) {
        if ($description -eq $null) { $description =  "No Description" }
        set-assemblymeta "Description" $description $path
    } else {
        write-verbose "found Description: $v"
    }
    
    $v = get-assemblymeta "Company" $path
    if ([string]::isnullorempty($v) -or $company -ne $null) {
        if ($company -eq $null) { $company =  "MyCompany" }
        set-assemblymeta "Company" $company $path
    } else {
        write-verbose "found Company: $v"
    }
   
   Update-AssemblyVersion $version $path
}

new-alias push-nuget invoke-nugetpush
new-alias pack-nuget invoke-nugetpack
new-alias generate-nuspec new-nuspec

export-modulemember -function * -alias *