ipmo process
ipmo assemblymeta -Global
ipmo semver -Global


$root = "."
if (![string]::IsNullOrEmpty($PSScriptRoot)) {
    $root = $PSScriptRoot
}
#if ($MyInvocation.MyCommand.Definition -ne $null) {
#    $root = $MyInvocation.MyCommand.Definition
#}
$helpersPath = $root
@("choco-utils.ps1", "internal.ps1", "nuget-helpers.ps1") |
    % { 
        $p = get-item "$root/functions/$_"
        . $p.fullname
    }


function Expand-ZIPFile
{
[CmdletBinding()]
param($file, $destination)
    $shell = new-object -com shell.application
    $zip = $shell.NameSpace($file)
    foreach($item in $zip.items())
    {
        write-verbose "extracting $($item.Name) to $destination"
        $shell.Namespace($destination).copyhere($item, 0x14)
    }
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
    param(
    [Parameter(ValueFromPipeline=$true,Position=0)] $file = $null, 
    [Parameter(Mandatory=$false)] $source,
    [Parameter(Mandatory=$false)] $apikey,
    [switch][bool]$Symbols,
    [switch][bool] $Build,
    [switch][bool] $ForceDll,
    [switch][bool] $Stable,
    [switch][bool] $useDotnet,
    $buildProperties = @{}) 
process {
    
    if ($file -eq $null -and !$build) {
        $files = @(get-childitem -filter "*.nupkg" | sort LastWriteTime -Descending)
        if ($files.length -gt 0){
            $file = $files[0].name
        }
    }
    if ($file -eq $null -or !($file.EndsWith(".nupkg"))){
        $nupkg = invoke-nugetpack $file -Build:$build -symbols:$symbols -stable:$stable -forceDll:$forceDll -buildProperties  $buildProperties -usedotnet:$usedotnet
    } else {
        $nupkg = $file
    }
    #in case multiple nupkgs are created
    if ($symbols) {
        $symbolpkg = @($nupkg) | ? { $_ -match "-symbols\." } | select -last 1
        $nupkg = $symbolpkg
        $nosymbolspkg = $nupkg -replace "\.symbols\.","."
        if (test-path $nosymbolspkg) {
            write-verbose "copying '$nosymbolspkg' to '$($nupkg -replace "\.symbols\.",".nosymbols.")'"
            copy-item $nosymbolspkg "$($nupkg -replace "\.symbols\.",".nosymbols.")" 
        }
        write-host "push Symbols package: replacing $nosymbolspkg with $symbolpkg"
        copy-item $symbolpkg $nosymbolspkg -Force
        $nupkg = $nosymbolspkg
    } else {
        $nupkg = @($nupkg)| ? { $_ -notmatch "\.symbols\." }  | select -last 1

    }

    $sources = @($source)
    foreach($source in $sources) {
        Write-Host "pushing package $nupkg to $source"
        $p = @(
            $nupkg
        )

        # TODO: handle rolling updates for dotnet/dnx/nuget3 model
        if ($source -eq "rolling") {
            $packagesDir = find-packagesdir
            $packagename = (split-packagename (split-path -leaf $nupkg)).Name
            $nuget = find-nugetPath $packagename -packagesRelPath $packagesDir
            $packagedir = $nuget.PackageDir
            $zip = "$nupkg.zip"
            copy-item $nupkg $zip

            Expand-ZIPFile -file $zip -destination $packageDir -verbose
            copy-item $nupkg $packageDir -Verbose

        }
        else {
            if ($source -ne $null) {
                $p += "-source",$source
            }
            if ($apikey -ne $null) {
                $p += "-apikey",$apikey
            }
        
            if ($PSCmdlet.ShouldProcess("pushing package $p")) {
                write-verbose "nuget push $p"
                $o = nuget push $p | % { $_ | write-indented -level 4; $_ } 
                if ($lastexitcode -ne 0) {
                    throw "nuget command failed! `r`n$($o | out-string)"
                }
                write-output $nupkg
            }
        }
    }
}
}

function invoke-nugetpack {
    [CmdletBinding()]
    param(
    [Parameter(ValueFromPipeline=$true,Position=0)]
    $nuspecOrCsproj = $null,
    [switch][bool] $Build,
    [switch][bool] $Symbols,
    [switch][bool] $NoProjectReferences,
    [switch][bool] $Stable,
    [switch][bool] $ForceDll,
    [switch][bool] $useDotnet,
    $buildProperties = @{}) 
process {    
    pushd
    try {
        if ($nuspecorcsproj -ne $null -and (test-path $nuspecOrCsproj) -and (get-item $nuspecorcsproj).PsIsContainer) {
            cd $nuspecorcsproj
            $nuspecorcsproj = $null
        } 
        if ($nuspecorcsproj -eq $null) {
            $csprojs = @(gci . -filter "*.csproj") 
            if ($csprojs.Length -eq 0) {
                $csprojs += @(gci . -filter "project.json")  
            }
            if ($csprojs.length -eq 1) {
                $nuspecorcsproj = $csprojs[0].Name
            } else {
                throw "found multiple csproj/project.json files in '$((gi .).FullName)'. please choose one."
            }
        }
        if ($nuspecorcsproj -eq $null) {
            $csprojs = @(gci . -filter "*.nuspec")
            if ($csprojs.length -eq 1) {
                $nuspecorcsproj = $csprojs[0].Name
            } else {
                throw "found multiple nuspec files in '$((gi .).FullName)'. please choose one."
            }
        }
        $dotnet = "dnu"
        if ($useDotnet) { $dotnet = "dotnet" }
        
        $dir = split-path -parent $nuspecorcsproj
        $nuspecorcsproj = split-path -Leaf $nuspecorcsproj
        write-verbose "packing nuget for $(split-path -leaf $nuspecorcsproj) in $dir"
    
        cd $dir

        if ($Build) {
            $newver = update-buildversion 
            if ($stable) {
                $newver = update-buildversion -stable:$stable
            }
            if ($nuspecorcsproj.endswith("project.json")) {
                    $o = invoke $dotnet restore -verbose:$($verbosePreference="Continue")
                    $o = invoke $dotnet build -verbose:$($verbosePreference="Continue")
            }
            else {
                $a = @()
                if ($forceDll) {
                    $a += @("-p:OutputType=Library")
                }
                if ($buildProperties -ne $null) {
                    $buildProperties.GetEnumerator() | % { $a += @("-p:$($_.Key)=$($_.Value)") }
                }
                write-host "building project: msbuild $nuspecorcsproj $a "
                $o = msbuild $nuspecorcsproj $a | % { $_ | write-indented -level 4; $_ }
                if ($lastexitcode -ne 0) {
                throw "build failed! `r`n$($o | out-string)"
                }
            }
        }
    
        if ($nuspecorcsproj.endswith("project.json")) {
            $a = @() 
            
            $o = invoke $dotnet pack $a -verbose:$($verbosePreference="Continue")
            $success = $o | % {
                    if ($_ -match "(?<project>.*) -> (?<nupkg>.*\.nupkg)") {
                        return $matches["nupkg"]
                    }
            }
            return $success
        }
        else {
            $a = @() 
            if ($forcedll) {
                $tmpproj = "$nuspecorcsproj.tmp.csproj" 
                copy-item $nuspecOrCsproj $tmpproj -Force
                $c = get-content $tmpproj
                $c = $c | % { $_ -replace "<OutputType>Exe</OutputType>","<OutputType>Library</OutputType>" } 
                $c | out-string | out-file $tmpproj -Encoding utf8
                
                $a += @(
                    "$tmpproj"
                )        
            } else {    
                $a += @(
                    "$nuspecorcsproj"
                )     
            }
            if (!$noprojectreferences) {
                $a += "-IncludeReferencedProjects"
            }
            if ($symbols) {
                $a += "-Symbols"
            }
            
            if ($buildProperties -ne $null) {
                    $properties = ""
                    $buildProperties.GetEnumerator() | % { $properties += "$($_.Key)=$($_.Value);" }
                    if (![string]::IsNullOrEmpty($properties)) {
                        $a += @("-Properties","$properties")
                    }
                }
            
            write-host "packing nuget: nuget pack $a"
            
            $o = nuget pack $a | % { $_ | write-indented -level 4; $_ } 
            if (($tmpproj -ne $null) -and (test-path $tmpproj)) { 
                remove-item $tmpproj
            }
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
    } finally {
        popd
    }
}
}


function update-nugetmeta {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param($path = ".", $description = $null, [Alias("company")]$author = $null, $version = $null)
    $verb = $psBoundParameters["Verbose"] -eq $true
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
   
   Update-AssemblyVersion $version $path -Verbose:$verb
}



function get-vcsname($path = ".") {
    $reporoot = $null
     $path = (get-item $path).FullName
        if (!(get-item $path).PsIsContainer) {
            $dir = split-path -Parent $path
        }
        else {
            $dir = $path
        }
        while(![string]::IsNullOrEmpty($dir)) {
            if ((test-path "$dir/.hg") -or (Test-Path "$dir/.git")) {
                $reporoot = $dir
                break;
            }
            $dir = split-path -Parent $dir
        }
     if ($reporoot -ne $null) {         
        if (test-path "$reporoot/.hg") { return "hg" }
        if (test-path "$reporoot/.git") { return "git" }
     }   
     
     return $null
    
}

function get-vcsbranch() {
    $vcs = get-vcsname   
    $branch = $null
    if ($vcs -eq "hg") { $branch = hg branch }
    elseif ($vcs -eq "git") { $branch = git rev-parse --abbrev-ref HEAD }
    
    return $branch
}
function get-vcsrev() {
    $id = $null
    $vcs = get-vcsname   
     if ($vcs -eq "hg") {
        $id = (hg id -i)
    } 
    elseif ($vcs -eq "git") {
        $id = (git rev-parse --short HEAD)
    }
    
    return $id
}

function Update-BuildVersion {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(ValueFromPipeline=$true, Position = 0)]
        $path = ".",
        [Parameter(Position = 1)]
        $version = $null,
        [VersionComponent]$component = [VersionComponent]::SuffixBuild,
        [switch][bool] $stable
        
    ) 
process {
    $verb = $psBoundParameters["Verbose"] -eq $true
    write-verbose "verbosity switch: $verb"
    pushd
    try {
        if ($path -ne $null) {
            $i = gi $path
            if (!$i.PsIsContainer) {
                $path = split-path -parent $path
            } 
            cd $path 
        }
        if ($version -eq $null) {
            
        }
        if ($version -eq $null -and $path -ne $null) {
            $ver = Get-AssemblyMeta InformationalVersion -verbose:$verb
            if ($ver -eq $null) { $ver = Get-AssemblyMeta Version -verbose:$verb }
        }
        else {
            $ver = $version
        }
        
        $newver = $ver
        if ($newver -eq $null) {
            # maybe the version is linked from some other file?
            # do nothing
            return $newver
        }
        if ($newver -eq "1.0.0.0") {
            $newver = "1.0.0"
            $newver = Update-Version $newver Patch -nuget -verbose:$verb
        }

        if ($newver -match "\.\*") {
            $newver = $newver.trim(".*")
            $splits = $newver.Split(".")
            $c= $splits.Length - 1
            if ($component -eq $null -or $component -gt $c) {
                $newver = Update-Version $newver $c -nuget -verbose:$verb    
            }
        }        

        if ($newver.split(".").length -lt 3) {
            1..(3-$newver.split(".").Length) | % {
                $newver += ".0"
            }
        }

        $branch = get-vcsbranch -verbose:$verb
        if ($branch -ne $null) {
            $branchname = $branch 
            if ($branchname.StartsWith("release")) {
                $branchname = $branchname -replace "/","-" -replace "_","-" -replace "[0-9]","" -replace "-","" -replace "release","rc-"
                $branchname = $branchname.Trim("-")
            }
            write-verbose "found branch '$branch' => '$branchname'"            
            $newver = Update-Version $newver SuffixBranch -value $branchname -verbose:$verb
        }
       
       
       
        

        if ($component -ne $null) {
            $newver = Update-Version $newver $component -nuget -verbose:$verb    
        } else {
            $newver = Update-Version $newver SuffixBuild -nuget -verbose:$verb
        }
        
        #Write-Verbose "updating version $ver to $newver"
        try {
            write-verbose "getting source control revision id"
            $id = get-vcsrev -verbose:$verb
            write-verbose "rev id='$id'"
        } catch {
            write-warning "failed to get vcs rev"
        }
        if ($id -ne $null) {
            $id = $id.substring(0,5)
            $newver = Update-Version $newver SuffixRevision -value $id -nuget -verbose:$verb
        } else {
            write-warning "vcs rev returned null"
        }
        
        if ($stable) {
            $newver = update-version $newver Suffix -value "" -nuget -verbose:$verb
        }

        
        Write-host "updating version $ver to $newver"
        if ($path -ne $null -and $version -eq $null -and $PSCmdlet.ShouldProcess("update version $ver to $newver")) {
            update-nugetmeta -version $newver -verbose:$verb
        }
        return $newver
    } 
    catch {
        throw $_
    }
    finally {
        popd
    }
}
}

new-alias generate-nugetmeta update-nugetmeta
new-alias push-nuget invoke-nugetpush
new-alias pack-nuget invoke-nugetpack
new-alias generate-nuspec new-nuspec

export-modulemember -function * -alias *