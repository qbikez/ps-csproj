# ipmo process
# ipmo assemblymeta -Global
# ipmo semver -Global
# ipmo newtonsoft.json
# ipmo pathutils

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


function Expand-ZIPFile {
    [CmdletBinding()]
    param($file, $destination)
    if (!(test-path $file)) { throw "zip file '$file' not found in '$((get-item .).FullName)'" }
    $shell = new-object -com shell.application
    $zip = $shell.NameSpace((get-item $file).FullName)
    if ($zip -eq $null) { throw "failed to open zipfile '$file'" }
    try {
        foreach ($item in $zip.items()) {
            write-verbose "extracting $($item.Name) to $destination"
            if ($item.name -eq "lib") {                
                $shell.Namespace((get-item $destination).fullname).copyhere($item, 0x14)
            }
            else {
                $shell.Namespace((get-item $destination).fullname).copyhere($item, 0x14)
            }
        }
    }
    catch {
        throw (New-Object System.Exception "Failed to extract zip '$file' to '$destination'", $_.Exception)
    }
}

function new-nuspec($projectPath = ".") {
    pushd
    try {
        if (!(test-path $projectpath)) { throw "file '$projectPath' not found" }
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
    }
    finally {
        popd
    }
}

function Get-InstalledNugets($packagesdir) {
    $subdirs = get-childitem $packagesdir -Directory
    $result = @()
    foreach ($s in $subdirs) {
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
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(ValueFromPipeline = $true, Position = 0)] $file = $null, 
        [Parameter(Mandatory = $false)] $source,
        [Parameter(Mandatory = $false)] $apikey,
        [switch][bool] $Symbols,
        [switch][bool] $Build,
        [switch][bool] $ForceDll,
        [switch][bool] $Stable,
        [switch][bool] $useDotnet,
        [Alias("newVersion")]
        [switch][bool] $incrementVersion,
        [switch][bool] $keepVersion,
        $suffix = $null,
        $branch = $null,
        $buildProperties = @{ }) 
    process {
        if ($stable -and $incrementVersion) {
            throw "-Stable cannot be used with -incrementVersion"
        }

        $bound = $PSBoundParameters
        if ($bound.stable -eq $null) {
            $Symbols = !$stable
        }
        if ($bound.build -eq $null) {
            # build dev packages by default
            if (!$stable) { $build = $true }
            # build stable packages by default
            if ($stable) { $build = $true }
        }
        if ($file -eq $null -and !$build) {
            $files = @(get-childitem -filter "*.nupkg" | sort LastWriteTime -Descending)
            if ($Symbols) {
                $files = $files | ? { $_ -match "\.symbols\." }
            }
            if ($files.length -gt 0) {
                $file = $files[0].name
            }
            else {
                # will build
            }
        
        }
        if ($file -eq $null -or !($file.EndsWith(".nupkg"))) {
            $nupkg = invoke-nugetpack $file -Build:$build -symbols:$symbols -stable:$stable -forceDll:$forceDll -buildProperties:$buildProperties -usedotnet:$usedotnet -keepVersion:$keepVersion -suffix:$suffix -incrementVersion:$incrementVersion -branch:$branch
        }
        else {
            $nupkg = $file
        }
        #in case multiple nupkgs are created
        if ($symbols) {
            $symbolpkg = @($nupkg) | ? { $_ -match "\.symbols\." } | select -last 1
            if ($symbolpkg -ne $null) {
                $nupkg = $symbolpkg
                $nosymbolspkg = $nupkg -replace "\.symbols\.", "."
                if (test-path $nosymbolspkg) {
                    write-verbose "copying '$nosymbolspkg' to '$($nupkg -replace "\.symbols\.",".nosymbols.")'"
                    copy-item $nosymbolspkg "$($nupkg -replace "\.symbols\.",".nosymbols.")" 
                }
                write-host "push Symbols package: replacing $nosymbolspkg with $symbolpkg"
                copy-item $symbolpkg $nosymbolspkg -Force
                $nupkg = $nosymbolspkg
            }
            else {
                write-warning "did not find a matching .symbols.nupkg package"
                $nupkg = @($nupkg) | ? { $_ -notmatch "\.symbols\." } | select -last 1
            }
        }
        else {
            $nupkg = @($nupkg) | ? { $_ -notmatch "\.symbols\." } | select -last 1

        }

        if ($nupkg -eq $null) {
            throw "no nupkg produced"
        }

        $nupkg = (get-item $nupkg).FullName

        if ($source -eq $null) {
            $source = $env:NUGET_PUSH_SOURCE
            if ($source -ne $null) {
                write-warning "pushing to default source from `$env:NUGET_PUSH_SOURCE=$env:NUGET_PUSH_SOURCE"
            }
            else {
                Write-Warning "If you want to push to nuget, set `$env:NUGET_PUSH_SOURCE variable to target feed"
                return
            }
        }

        $sources = @($source)
        foreach ($source in $sources) {
            if ($source -eq $null) {
                write-error "no source specified. skipping push."
                continue
            }
            Write-Host "pushing package '$nupkg' to '$source'"
            $p = @(
                $nupkg
                "-NonInteractive"
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
                
                    foreach ($packagesDir in $packagesDirs) {        
                        $nuget = find-nugetPath $packagename -packagesRelPath $packagesDir -versionhint $versionhint
                        $packagedir = $nuget.PackageDir
                        if ($packagedir -eq $null) {
                            write-warning "package dir for package '$packagename' (version=$versionhint) not found in '$packagesdir'"
                            continue
                        }
                        $zip = "$nupkg.zip"
                        copy-item $nupkg $zip

                    
                        Expand-ZIPFile -file $zip -destination $packageDir -verbose
                        copy-item $nupkg $packageDir -Verbose
                        $lib = get-childitem $packageDir -Filter "lib"
                        if ($lib -ne $null) {
                            $frameworks = get-childitem ($lib.FullName)
                            foreach ($f in $frameworks) {
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
                }
                finally {
                    popd
                }
            }
            else {
                if ($source -ne $null -and $apikey -eq $null) {
                    # try to get apikey from cache
                    if ($null -eq (gmo cache)) {
                        ipmo cache -erroraction ignore -MinimumVersion 1.1.0
                    }
                    if ($null -eq $apikey -and $null -ne (gmo cache)) {
                        $apikey = get-passwordcached $source
                        if ($apikey -ne $null) { write-verbose "found cached api key for source $source" }
                    }                

                    #try to get api key from global settings
                    if ($null -eq (gmo cache)) {
                        ipmo cache -erroraction ignore -MinimumVersion 1.1.0
                    }
                    if ($null -eq $apikey -and $null -ne (gmo cache)) {
                        $settings = cache\import-settings
                        if ($settings -ne $null) {
                            $apikey = $settings["$source.apikey"]
                            if ($apikey -ne $null) {
                                $cred = new-object "system.management.automation.pscredential" "dummy", $apikey
                                $apikey = $cred.GetNetworkCredential().Password
                                if ($apikey -ne $null) { write-verbose "found api key in globalsettings for source $source" }
                            }
                        }
                    }
                }

                if ($source -ne $null) {
                    $p += "-source", $source
                }
                if ($apikey -ne $null) {
                    write-verbose "using apikey $apikey"
                    $p += "-apikey", $apikey
                }
                else {
                    write-verbose "no apikey found"
                }
        
                if ($PSCmdlet.ShouldProcess("pushing package '$p'")) {
                    write-verbose "nuget push $p"
                    $o = invoke nuget push @p -passthru -verbose -nothrow -WhatIf:($WhatIfPreference)
                    if ($lastexitcode -ne 0) {
                        $summary = $o | select -last 1
                        if ($summary -is [System.Management.Automation.ErrorRecord]) { $summary = $summary.Exception.Message }
                        throw "nuget command failed! `r`n$summary"
                    }                
                }
            }
        }

        write-output $nupkg
    }
}

function invoke-nugetpack {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, Position = 0)]
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
        $branch = $null,
        [switch][bool] $keepVersion,
        $buildProperties = @{ }) 
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
                }
                else {
                    throw "found multiple csproj/project.json files in '$((gi .).FullName)'. please choose one."
                }
            }
            if ($nuspecorcsproj -eq $null) {
                $csprojs = @(gci . -filter "*.nuspec")
                if ($csprojs.length -eq 1) {
                    $nuspecorcsproj = $csprojs[0].Name
                }
                else {
                    throw "found multiple nuspec files in '$((gi .).FullName)'. please choose one."
                }
            }

            if ($incrementVersion -and !$build) {
                throw "-incrementVersion has no meaning when used without -build"
            }
            if ($nuspecorcsproj.endswith("project.json")) {
                $useDotnet = $true
                $dotnet = get-dotnetcommand
                if ($dotnet -eq $null) { $dotnet = "dotnet" }
                if ($useDotnet) { $dotnet = "dotnet" }
            }
        
            $packDotnet = $false;
            if ($nuspecOrCsproj.endswith("csproj")) { 
                if ($useDotnet) {
                    $dotnet = get-dotnetcommand;
                    if ($dotnet -eq $null) { $dotnet = "dotnet" }
                    
                    $xml = [xml](get-content $nuspecOrCsproj)
                    if ($xml.Project.sdk -ne $null) {
                        $packDotnet = $true;
                        write-verbose "using 'dotnet' for this csproj (SDK attribute is set in xml)"
                    }
                    else {
                        $packDotnet = $false;
                        write-verbose "using 'dotnet' for this csproj (UseDotnet is true)"
                    }
                
                }
                else {
                    $packDotnet = $false;
                    write-verbose "using standard 'nuget' for this csproj (SDK attribute is NOT set in xml)"
                }
            }

            $dir = split-path -parent $nuspecorcsproj
            if ([string]::isnullorempty($dir)) { $dir = "." }
            $nuspecorcsproj = split-path -Leaf $nuspecorcsproj
            write-verbose "packing nuget for $(split-path -leaf $nuspecorcsproj) in $((get-item $dir).fullname)"
            
            cd $dir

            if ($suffix -ne $null) {
                $newver = update-buildversion -component Suffix -value $suffix
            }
            else {
                if ($incrementVersion) { $newver = update-buildversion -component patch } 
                elseif (!$keepversion) { $newver = update-buildversion } 
                if ($branch -ne $null) {
                    $newver = update-buildversion -component SuffixBranch -value $branch
                }
                if ($stable) {
                    $newver = update-buildversion -stable:$stable
                }
            }

            if ($Build) {
                invoke-build $nuspecorcsproj -Stable:$stable -forceDll:$forceDll -buildProperties:$buildProperties -usedotnet:$usedotnet -keepVersion:$keepVersion -suffix:$suffix -incrementVersion:$incrementVersion -branch:$branch -newver:$newver
            }
    
            if ($packDotnet) { 
                $a = @() 
            
                $o = invoke $dotnet pack @a -verbose -passthru -nobuild -version $newver
                $success = $o | % {
                    if ($_ -match "(?<project>.*) -> (?<nupkg>.*\.nupkg)") {
                        return $matches["nupkg"]
                    }
                    if ($_ -match "Successfully created package '(?<nupkg>.*\.nupkg)'") {
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
                    $c = $c | % { $_ -replace "<OutputType>Exe</OutputType>", "<OutputType>Library</OutputType>" } 
                    $c | out-string | out-file $tmpproj -Encoding utf8
                
                    $a += @(
                        "$tmpproj"
                    )        
                }
                else {    
                    $a += @(
                        "$nuspecorcsproj"
                    )     
                }

                $a += "-Version" 
                $a += $newver
            
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
                        $a += @("-Properties", "$properties")
                    }
                }
            
                write-host "packing nuget"
            
                $o = invoke nuget pack @a -passthru

                if (($tmpproj -ne $null) -and (test-path $tmpproj)) { 
                    remove-item $tmpproj
                }
                if ($lastexitcode -ne 0) {
                    throw "nuget command failed! `r`n$($o | out-string)"
                }
                else {
                    $success = $o | % {
                        if ($_ -match "Successfully created package ['\`"](.*)['\`"]") {
                            return $matches[1]
                        }
                        if ($_ -match "utworzono pakiet ['\`"](.*)['\`"]") {
                            return $matches[1]
                        }
                    }
             
                    return $success | select -unique
                }
            }
        }
        finally {
            popd
        }
    }
}

function invoke-build {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, Position = 0)]
        $nuspecOrcsproj = $null,
        [switch][bool] $Symbols,
        [switch][bool] $NoProjectReferences,
        [switch][bool] $Stable,
        [switch][bool] $ForceDll,
        [switch][bool] $useDotnet,
        [Alias("newVersion")]
        [switch][bool] $incrementVersion,
        $suffix = $null,
        $branch = $null,
        [switch][bool] $keepVersion,
        $newver = $null,
        $buildProperties = @{ }) 
    process {    
        pushd
        try {
            if ($nuspecOrcsproj.endswith(".nuspec")) {
                $csproj = $nuspecOrcsproj.replace(".nuspec", ".csproj")
            }
            else {
                $csproj = $nuspecOrcsproj
            }
            if ($csproj -ne $null -and (test-path $csproj) -and (get-item $csproj).PsIsContainer) {
                cd $csproj
                $csproj = $null
            } 
            if ($csproj -eq $null) {
                $csprojs = @(gci . -filter "*.csproj") 
                if ($csprojs.Length -eq 0) {
                    $csprojs += @(gci . -filter "project.json")  
                }
                if ($csprojs.length -eq 1) {
                    $csproj = $csprojs[0].Name
                }
                else {
                    throw "found multiple csproj/project.json files in '$((gi .).FullName)'. please choose one."
                }
            }
            if ($csproj -eq $null) {
                $csprojs = @(gci . -filter "*.nuspec")
                if ($csprojs.length -eq 1) {
                    $csproj = $csprojs[0].Name
                }
                else {
                    throw "found multiple nuspec files in '$((gi .).FullName)'. please choose one."
                }
            }

            if ($csproj.endswith("project.json")) {
                $useDotnet = $true
                $dotnet = get-dotnetcommand
                if ($dotnet -eq $null) { $dotnet = "dotnet" }
                if ($useDotnet) { $dotnet = "dotnet" }
            }
        
            $dir = split-path -parent $csproj
            if ([string]::isnullorempty($dir)) { $dir = "." }
            $csproj = split-path -Leaf $csproj
            write-verbose "building project for $(split-path -leaf $csproj) in $((get-item $dir).fullname)"
            
            cd $dir

            if($newver -ne $null)
            {
                # Update-Version $csproj -value $newver
            }
            else {
                if ($suffix -ne $null) {
                    $newver = update-buildversion -component Suffix -value $suffix
                }
                else {
                    if ($incrementVersion) { $newver = update-buildversion -component patch } 
                    elseif (!$keepversion) { $newver = update-buildversion  } 
                    if ($branch -ne $null) {
                        $newver = update-buildversion  -component SuffixBranch -value $branch
                    }
                    if ($stable) {
                        $newver = update-buildversion  -stable:$stable
                    }
                }
                    
            }
            
            if ($useDotnet) {
                # don't restore - if user has just built the project, it is already restored
                # if not, dotnet will detect out-of-date project.lock.json and build will fail
                #$o = invoke $dotnet restore -verbose:$($verbosePreference="Continue") -passthru
                $dotnet = get-dotnetcommand
                if ($dotnet -eq $null) { $dotnet = "dotnet" }
                $o = invoke $dotnet build -verbose:$($verbosePreference = "Continue") -passthru
            }
            else {
                $a = @()
                if ($forceDll) {
                    $a += @("-p:OutputType=Library")
                }
                if ($buildProperties -ne $null) {
                    $buildProperties.GetEnumerator() | % { $a += @("-p:$($_.Key)=$($_.Value)") }
                }
                write-host "building project: msbuild $csproj $a "
                $o = invoke msbuild $csproj $a -passthru                
            }
                
        }
        finally {
            popd
        }
    }
}

function update-nugetmeta {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param($path = ".", $description = $null, [Alias("company")]$author = $null, $version = $null)
    
    $verb = $psBoundParameters["Verbose"] -eq $true
    write-verbose "generating nuget meta"
    $v = get-assemblymeta "Description" $path
    if ([string]::isnullorempty($v) -or $description -ne $null) {
        if ($description -eq $null) { $description = "no description" }
        set-assemblymeta "Description" $description $path
    }
    else {
        write-verbose "found Description: $v"
    }
    
    $v = get-assemblymeta "Company" $path   
    if ([string]::isnullorempty($v) -or $company -ne $null) {
        if ($company -eq $null) { $company = "MyCompany" }
        set-assemblymeta "Company" $company $path
    }
    else {
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
    while (![string]::IsNullOrEmpty($dir)) {
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
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(ValueFromPipeline = $true, Position = 0)]
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
                $c = $splits.Length - 1
                if ($component -eq $null -or ($component -gt $c -and $value -eq $null)) {
                    $newver = Update-Version $newver $c -nuget -verbose:$verb    
                }
            }        

            if ($newver.split(".").length -lt 3) {
                1..(3 - $newver.split(".").Length) | % {
                    $newver += ".0"
                }
            }

            $branch = get-vcsbranch -verbose:$verb
            if ($branch -ne $null) {
                $branchname = $branch 
                if ($branchname.StartsWith("release")) {
                    $branchname = $branchname -replace "/", "-" -replace "_", "-" -replace "[0-9]", "" -replace "-", "" -replace "release", "rc-"
                    $branchname = $branchname.Trim("-")
                }
                write-verbose "found branch '$branch' => '$branchname'"            
                $newver = Update-Version $newver SuffixBranch -value $branchname -verbose:$verb
            }
       
       
       
        

            if ($component -ne $null) {
                $newver = Update-Version $newver $component -nuget -verbose:$verb -value $value  
            }
            else {
                $newver = Update-Version $newver SuffixBuild -nuget -verbose:$verb
            }
        
            if ($component -ne [VersionComponent]::Suffix -or $value -eq $null) {
                #Write-Verbose "updating version $ver to $newver"
                try {
                    write-verbose "getting source control revision id"
                    $id = get-vcsrev -verbose:$verb
                    write-verbose "rev id='$id'"
                }
                catch {
                    write-warning "failed to get vcs rev"
                }
                if ($id -ne $null) {
                    $id = $id.substring(0, 5)
                    $newver = Update-Version $newver SuffixRevision -value $id -nuget -verbose:$verb
                }
                else {
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
            }
            else {

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
    [CmdletBinding()]
    param()
    $global = find-globaljson
    if ($global -eq $null) { write-verbose "dotnet: no global.json found for dir $((get-item .).FullName)"; return $null }
    $json = get-content $global | out-string | ConvertFrom-JsonNewtonsoft
    $default = "dotnet"
    if ($json.sdk -eq $null) { write-verbose "dotnet: no sdk version specified in '$global'"; return $default }
    if ($json.sdk.version -eq $null) { write-verbose "dotnet: no sdk version specified in '$global'"; return $default }
    if ($json.sdk.version.startswith("1.0.0-beta") -or $json.sdk.version.startswith("1.0.0-rc2")) {
        write-verbose "dotnet: sdk version='$($json.sdk.version)'. using dnu"
        return "dnu"
    } 
    else {
        write-verbose "dotnet: sdk version='$($json.sdk.version)'. using dotnet"
        return "dotnet"
    }
}

new-alias generate-nugetmeta update-nugetmeta -Force
new-alias push-nuget invoke-nugetpush -Force
new-alias pack-nuget invoke-nugetpack -Force
new-alias generate-nuspec new-nuspec -Force
new-alias build-project invoke-build -Force

export-modulemember -function * -alias *
