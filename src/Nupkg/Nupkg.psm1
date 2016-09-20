ipmo process
ipmo assemblymeta -Global
ipmo semver -Global
ipmo newtonsoft.json
ipmo pathutils

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
    if (!(test-path $file)) { throw "zip file '$file' not found in '$((get-item .).FullName)'" }
    $shell = new-object -com shell.application
    $zip = $shell.NameSpace((get-item $file).FullName)
    if ($zip -eq $null) { throw "failed to open zipfile '$file'" }
    try {
        foreach($item in $zip.items())
        {
            write-verbose "extracting $($item.Name) to $destination"
            if ($item.name -eq "lib") {                
                $shell.Namespace((get-item $destination).fullname).copyhere($item, 0x14)
            } else {
                $shell.Namespace((get-item $destination).fullname).copyhere($item, 0x14)
            }
        }
    } catch {
        throw (New-Object System.Exception "Failed to extract zip '$file' to '$destination'", $_.Exception)
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
    $l = invoke nuget list -source $source -passthru -silent
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
    [Alias("newVersion")]
    [switch][bool] $incrementVersion,
    $suffix = $null,
    $buildProperties = @{}) 
process {
    if ($stable -and $incrementVersion) {
        throw "-Stable cannot be used with -incrementVersion"
    }
    if ($file -eq $null -and !$build) {
        $files = @(get-childitem -filter "*.nupkg" | sort LastWriteTime -Descending)
        if ($files.length -gt 0){
            $file = $files[0].name
        }
    }
    if ($file -eq $null -or !($file.EndsWith(".nupkg"))){
        $nupkg = invoke-nugetpack $file -Build:$build -symbols:$symbols -stable:$stable -forceDll:$forceDll -buildProperties:$buildProperties -usedotnet:$usedotnet -suffix:$suffix -incrementVersion:$incrementVersion
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

    if ($nupkg -eq $null) {
        throw "no nupkg produced"
    }

    $sources = @($source)
    foreach($source in $sources) {
        Write-Host "pushing package '$nupkg' to '$source'"
        $p = @(
            $nupkg
        )

        # TODO: handle rolling updates for dotnet/dnx/nuget3 model
        if ($source.startsWith("rolling")) {
            
            pushd
            try {
                $versionhint = $null

                if ($source -match "rolling:(.*):v(.*)") {
                    cd $matches[1]
                    $versionhint = $matches[2]
                }
                elseif ($source -match "rolling:v(.*)") {
                    $versionhint = $matches[1]
                }
                elseif ($source -match "rolling:(.*)") {
                    cd $matches[1]
                }
            
                
                $packagesDirs = find-packagesdir -all
                if ($packagesDirs -eq $null) { throw "packages dir not found" }
                write-host "rolling source specified. Will extract to $packagesDirs"    
                $packagename = (split-packagename (split-path -leaf $nupkg)).Name
                
                foreach($packagesDir in $packagesDirs) {        
                    $nuget = find-nugetPath $packagename -packagesRelPath $packagesDir -versionhint $versionhint
                    $packagedir = $nuget.PackageDir
                    if ($packagedir -eq $null) {
                        write-warning "package dir for package '$packagename' not found in '$packagesdir'"
                        continue
                    }
                    $zip = "$nupkg.zip"
                    copy-item $nupkg $zip

                    
                    Expand-ZIPFile -file $zip -destination $packageDir -verbose
                    copy-item $nupkg $packageDir -Verbose
                    $lib = get-childitem $packageDir -Filter "lib"
                    if($lib -ne $null) {
                        $frameworks = get-childitem ($lib.FullName)
                        foreach($f in $frameworks) {
                            if ($f.name.contains("%")) {
                                [Reflection.Assembly]::LoadWithPartialName("System.Web") | Out-Null
                                $decoded = $([System.Web.HttpUtility]::UrlDecode($f.fullname))
                                if ($decoded -ne $f.fullname) {
                                    if (test-path $decoded) { rmdir $decoded -Force -Recurse }
                                    Rename-Item -path $($f.fullname) -NewName $decoded -Verbose -Force
                                }
                            }
                        }
                    }

                }
            } finally {
                popd
            }
        }
        else {
            if ($source -ne $null -and $apikey -eq $null) {
                # try to get apikey from cache
                if ($null -eq (gmo cache)) {
                    ipmo cache -erroraction ignore
                }
                if ($null -ne (gmo cache)) {
                    $apikey = get-passwordcached $source
                }
            }

            if ($source -ne $null) {
                $p += "-source",$source
            }
            if ($apikey -ne $null) {
                $p += "-apikey",$apikey
            }
        
            if ($PSCmdlet.ShouldProcess("pushing package '$p'")) {
                write-verbose "nuget push $p"
                $o = invoke nuget push @p -passthru -verbose -WhatIf:($WhatIfPreference)
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
    [Alias("newVersion")]
    [switch][bool] $incrementVersion,
    $suffix = $null,
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
        if ($nuspecorcsproj.endswith("project.json")) {
            $dotnet = get-dotnetcommand
            if ($dotnet -eq $null) { $dotnet = "dotnet" }
            if ($useDotnet) { $dotnet = "dotnet" }
        }
        
        $dir = split-path -parent $nuspecorcsproj
        $nuspecorcsproj = split-path -Leaf $nuspecorcsproj
        write-verbose "packing nuget for $(split-path -leaf $nuspecorcsproj) in $dir"
    
        cd $dir

        if ($Build) {
            if ($suffix -ne $null) {
                $newver = update-buildversion -component Suffix -value $suffix
            }
            else {
                if ($incrementVersion) { $newver = update-buildversion -component patch } 
                else { $newver = update-buildversion } 
                if ($stable) {
                    $newver = update-buildversion -stable:$stable
                }
            }
            if ($nuspecorcsproj.endswith("project.json")) {
                    $o = invoke $dotnet restore -verbose:$($verbosePreference="Continue") -passthru
                    $o = invoke $dotnet build -verbose:$($verbosePreference="Continue") -passthru
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
                $o = invoke msbuild $nuspecorcsproj $a -passthru                
            }
        }
    
        if ($nuspecorcsproj.endswith("project.json")) {
            $a = @() 
            
            $o = invoke $dotnet pack @a -verbose -passthru
            $success = $o | % {
                    if ($_ -match "(?<project>.*) -> (?<nupkg>.*\.nupkg)") {
                        return $matches["nupkg"]
                    }
            }
            
            # for some reason, dotnet pack results are duplicated
            <# 
            write-host "success:"
            foreach($l in $success) { write-host ": $l" }
            write-host "output:"
            foreach($l in $o) { write-host ": $l" }
            #>
            return $success | select -unique
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
            
            write-host "packing nuget"
            
            $o = invoke nuget pack @a -passthru -verbose
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
             
                return $success | select -unique
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
        if ($description -eq $null) { $description =  "no description" }
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
        [switch][bool] $stable,
        $value = $null
        
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
            $newver = Update-Version $newver $component -nuget -verbose:$verb -value $value  
        } else {
            $newver = Update-Version $newver SuffixBuild -nuget -verbose:$verb
        }
        
        if ($component -ne [VersionComponent]::Suffix -or $value -eq $null) {
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
        }
        
        if ($stable) {
            $newver = update-version $newver Suffix -value "" -nuget -verbose:$verb
        }

        
        Write-host "updating version $ver to $newver"
        if ($path -ne $null -and $PSCmdlet.ShouldProcess("update version $ver to $newver")) {
            $assemblyinfos = Get-AssemblyMetaFile -ErrorAction Ignore
            if ($assemblyinfos -ne $null) { update-nugetmeta -version $newver -verbose:$verb }
        } else {

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


function find-globaljson($path = ".") {
    ipmo pathutils
    return find-upwards "global.json" -path $path    
}


function get-dotnetcommand {
    $global = find-globaljson
    if ($global -eq $null) { return $null }
    $json = get-content $global | out-string | ConvertFrom-JsonNewtonsoft
    $default = "dotnet"
    if ($json.sdk -eq $null) { return $default }
    if ($json.sdk.version -eq $null) { return $default }
    if ($json.sdk.version.startswith("1.0.0-beta") -or $json.sdk.version.startswith("1.0.0-rc2")) {
        return "dnu"
    } 
    else {
        return "dotnet"
    }
}

new-alias generate-nugetmeta update-nugetmeta
new-alias push-nuget invoke-nugetpush
new-alias pack-nuget invoke-nugetpack
new-alias generate-nuspec new-nuspec

export-modulemember -function * -alias *
