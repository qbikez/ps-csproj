

function update-buildversion {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        $path = ".",
        $version = $null,
        [VersionComponent]$component = [VersionComponent]::SuffixBuild
    ) 
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
            $newver = Update-Version $newver Patch -nuget   
        }
        if ($newver -match "\.\*") {
            $newver = $newver.trim(".*")
            $splits = $newver.Split(".")
            $c= $splits.Length - 1
            if ($component -eq $null -or $component -gt $c) {
                $newver = Update-Version $newver $c -nuget    
            }
        }
        
        if ($newver.split(".").length -lt 3) {
            1..(3-$newver.split(".").Length) | % {
                $newver += ".0"
            }
        }
        

        if ($component -ne $null) {
            $newver = Update-Version $newver $component -nuget    
        } else {
            $newver = Update-Version $newver SuffixBuild -nuget
        }
        #Write-Verbose "updating version $ver to $newver"
        try {
        $id = (hg id -i)
        } catch {
            write-warning "failed to execute 'hg id'"
        }
        if ($id -ne $null) {
            $id = $id.substring(0,5)
            $newver = Update-Version $newver SuffixRevision -value $id -nuget
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
