
function find-nugetdll {
    param (
        [Parameter(Mandatory=$true)] $name, 
        [Parameter(Mandatory=$true)] $path
    )
     
    $dll = join-path $path "$name.dll"
    if (test-path $dll) { return $dll } 
    $dlls = @(gci $path -Filter "*.dll")
    if ($dlls.Length -eq 1) {
        return join-path $path $dlls[0].Name
    }

    return $null
}

function sort-frameworks([Parameter(ValueFromPipeline=$true)] $frameworks, $frameworkhint) {
begin {
    $ordered = @()
}
process {
    $order = switch($_.name) {
        $frameworkhint { 0; break }
        {$_ -match "^net" } { 10; break }
        {$_ -match "^dnx" }  { 20; break }
        default { 100; break }
    }
    $ordered += @( New-Object -type pscustomobject -Property @{
            dir = $_
            order = $order
        })
}
end {
    $ordered = $ordered | sort dir -Descending | sort order 
    return $ordered | select -ExpandProperty dir
    }
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

function new-nuspec($projectPath) {
    pushd
    try {
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
    [CmdletBinding()]
    param($file = $null, 
    [Parameter(Mandatory=$false)]$source,
    [Parameter(Mandatory=$false)]$apikey,
    [switch][bool] $Build) 
    
    if ($file -eq $null -or !($file.EndsWith(".nupkg"))){
        $nupkg = invoke-nugetpack $file -Build:$build
    } else {
        $nupkg = $file
    }
    Write-Verbose "pushing package $nupkg to $source"
    $p = @(
        $nupkg
    )
    if ($source -ne $null) {
        $p += "-source",$source
    }
    if ($apikey -ne $null) {
        $p += "-apikey",$apikey
    }
    $o = nuget push $p | % { write-verbose $_; $_ } 
    if ($lastexitcode -ne 0) {
        throw "nuget command failed! `r`n$($o | out-string)"
    } else {
        $o | % { write-host $_; }
    }
}

function invoke-nugetpack {
    [CmdletBinding()]
    param($nuspecOrCsproj = $null,
    [switch][bool] $Build) 
    
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
        $o = msbuild $nuspecorcsproj | % { write-verbose $_; $_ }
         if ($lastexitcode -ne 0) {
           throw "build failed! `r`n$($o | out-string)"
        }
    }
    
    $o = nuget pack $nuspecorcsproj | % { write-verbose $_; $_ } 
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
    param($path = ".", $description = $null, [Alias("company")]$author = $null, $version = $null, $suffix = $null)
    
    $v = get-assemblymeta "Description" $path
    if ($v -eq $null -or $description -ne $null) {
        if ($description -eq $null) { $description =  "No Description" }
        set-assemblymeta "Description" $description
    }
    
    $v = get-assemblymeta "Company" $path
    if ($v -eq $null -or $company -ne $null) {
        if ($company -eq $null) { $company =  "MyCompany" }
        set-assemblymeta "Company" $company
    }
   
    $v = get-assemblymeta "Version" $path
    if ($v -ne $null -and $suffix -ne $null) {
        if ($version -eq $null) { $version = $v }
        $version = "$version-$suffix"
    }
   
    
    $defaultVersion = "1.0.0"
    $ver = $version
    if ($ver -eq $null) { $ver = $defaultVersion } 
    
    if ($v -eq $null -or $v -eq "1.0.0.0" -or $version -ne $null) {
        set-assemblymeta "Version" ((split-packageversion $ver)["version"])
    }
    $v = get-assemblymeta "FileVersion" $path
    if ($v -eq $null -or $v -eq "1.0.0.0" -or $version -ne $null) {
        set-assemblymeta "FileVersion" ((split-packageversion $ver)["version"])
    }
        $v = get-assemblymeta "InformationalVersion" $path
    if ($v -eq $null -or $v -eq "1.0.0.0"  -or $version -ne $null) {
        set-assemblymeta "InformationalVersion" $ver
    }
}



if (-not ([System.Management.Automation.PSTypeName]'VersionComponent').Type) {
Add-Type -TypeDefinition @"
   public enum VersionComponent
   {
      Major = 0,
      Minor = 1,
      Patch = 2,
      Build = 3,
      Suffix = 4,
      SuffixBuild = 5,
      SuffixRevision = 6
   }
"@
}

function Update-Version([Parameter(mandatory=$true)]$ver, [VersionComponent]$component = [VersionComponent]::Patch, $value) {
    
    $null = $ver -match "(?<version>[0-9]+(\.[0-9]+)*)(-(?<suffix>.*)){0,1}"
    $version = $matches["version"]
    $suffix = $matches["suffix"]
    
    $vernums = $version.Split(@('.'))
    $lastNumIdx = $component
    if ($component -lt [VersionComponent]::Suffix) {
        $lastNum = [int]::Parse($vernums[$lastNumIdx])
        
        <# for($i = $vernums.Count-1; $i -ge 0; $i--) {
            if ([int]::TryParse($vernums[$i], [ref] $lastNum)) {
                $lastNumIdx = $i
                break
            }
        }#>
        if ($value -ne $null) {
            $lastNum = $value
        }
        else {
            $lastNum++
        }
        $vernums[$component] = $lastNum.ToString()
        #each lesser component should be set to 0 
        for($i = $component + 1; $i -lt $vernums.length; $i++) {
            $vernums[$i] = 0
        }
    } else {
        if ([string]::IsNullOrEmpty($suffix)) {
            #throw "version '$ver' has no suffix"
            $suffix = "build000"
        }
        
        if ($component -eq [VersionComponent]::SuffixBuild) {
            if ($suffix -match "build([0-9]+)") {
                $num = [int]$matches[1]
                if ($value -ne $null) {
                    $num = $value
                }
                else {
                    $num++
                }
                $suffix = $suffix -replace "build[0-9]+","build$($num.ToString("000"))"
            }
            else {
                throw "suffix '$suffix' does not match build[0-9] pattern"
            }
        }
        if ($component -eq [VersionComponent]::SuffixRevision) {
            if ($suffix -match "build([0-9]+)-(?<rev>[a-fA-F0-9]+)(-|$)") {
                $rev = $Matches["rev"]
                $suffix = $suffix -replace "$rev",$value
            }
            else {
                $suffix = $suffix + "-$value"
            }
        }
    }
    
    $ver2 = [string]::Join(".", $vernums)
    if (![string]::IsNullOrEmpty($suffix)) {
        $ver2 += "-$suffix"
    }

    return $ver2
}

function update-buildversion {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param($path = ".") 
    pushd
    try {
        cd $path
        $ver = Get-AssemblyMeta InformationalVersion
        if ($ver -eq $null) { $ver = Get-AssemblyMeta Version }
        $newver = Update-Version $ver SuffixBuild
        #Write-Verbose "updating version $ver to $newver"
        $id = (hg id -i).substring(0,5)
        $newver = Update-Version $newver SuffixRevision -value $id
        Write-Verbose "updating version $ver to $newver"
        if ($PSCmdlet.ShouldProcess("update version $ver to $newver")) {
            update-nugetmeta -version $newver
        }
    } finally {
        popd
    }
}

new-alias push-nuget invoke-nugetpush
new-alias pack-nuget invoke-nugetpack
new-alias generate-nugetmeta update-nugetmeta
new-alias increment-version update-version