import-module newtonsoft.json

function Initialize-Projects {
    [CmdletBinding()]
    param ($Path = ".") 

$_path = $path

ipmo deployment
$projectFiles = Get-Listing -Path $_path -files -include "*.csproj","*.xproj" -Recursive `
    -Excludes "node_modules/","artifacts/","bin/","obj/",".hg/","dnx-packages/","packages/","/common/","bower_components/","reader-content/","publish/"

$projects = @{}

$projectFiles | % {
    $name = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
    $path =  Get-RelativePath (gi .).fullname $_.fullname

    # $false and $true cause trouble when serializing with newtonsoft
    $hasNuspec = "false"
    try {
        $foundNuspec = test-path (join-path (split-path $path -Parent) "$name.nuspec")
        if ($foundNuspec) { $hasNuspec = "true" }
    } catch {
    }
    if ($projects.ContainsKey($name)) {
        write-warning "duplicate projects found: $($projects[$name])"
        write-warning "                     and  $path"
        $guid = [guid]::NewGuid().ToString("n")
        $projects += @{ "$($name)_$guid" = @{ path = $path; hasNuspec = $hasNuspec }} 
    } else {
        write-verbose "found project '$name' at '$path'"
        $projects += @{ "$name" = @{ path = $path; hasNuspec = $hasNuspec }} 
    }
    
}

$projects | convertto-jsonnewtonsoft | out-file (join-path $_path ".projects.json")

#$s =new-object -type "Newtonsoft.Json.JsonSerializerSettings"
#$s.ReferenceLoopHandling = [Newtonsoft.Json.ReferenceLoopHandling]::Ignore

write-host "Found $($projects.Count) projects"

}

New-Alias Scan-Projects Initialize-Projects