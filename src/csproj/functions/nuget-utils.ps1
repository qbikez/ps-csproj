ipmo nupkg
ipmo assemblymeta


function Update-BuildVersion {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        $path = ".",
        $version = $null,
        [VersionComponent]$component = [VersionComponent]::SuffixBuild
    ) 
    $verb = $psBoundParameters["Verbose"]
    write-verbose "verbosity switch: $verb"
    pushd
    try {
        if ($version -eq $null) {
            
        }
        if ($version -eq $null -and $path -ne $null) {
            $ver = Get-AssemblyMeta InformationalVersion 
            if ($ver -eq $null) { $ver = Get-AssemblyMeta Version }
        }
        else {
            $ver = $version
        }
        
        $newver = $ver
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
        

        if ($component -ne $null) {
            $newver = Update-Version $newver $component -nuget -verbose:$verb    
        } else {
            $newver = Update-Version $newver SuffixBuild -nuget -verbose:$verb
        }
        #Write-Verbose "updating version $ver to $newver"
        try {
            write-verbose "getting source control revision id"
            $id = (hg id -i)
            write-verbose "rev id='$id'"
        } catch {
            write-warning "failed to execute 'hg id'"
        }
        if ($id -ne $null) {
            $id = $id.substring(0,5)
            $newver = Update-Version $newver SuffixRevision -value $id -nuget -verbose:$verb
        } else {
            write-warning "'hg id -i' returned null"
        }
        Write-host "updating version $ver to $newver"
        if ($path -ne $null -and $version -eq $null -and $PSCmdlet.ShouldProcess("update version $ver to $newver")) {
            update-nugetmeta -version $newver
        }
        return $newver
    } finally {
        popd
    }
    
}

new-alias generate-nugetmeta update-nugetmeta
