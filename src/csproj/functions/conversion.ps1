function convert-projectReferencesToNuget {
    param([Parameter(Mandatory=$true, ValueFromPipeline=$true)][Sln] $sln)
    
    $projs = $sln.projects | ? { $_.type -eq "csproj" }
    
}

function get-referencesTo {
        [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)][Sln] $sln, 
        [Alias("project")][Parameter(Mandatory=$true)][string]$projectName
    )

     $projects = $sln | get-slnprojects
    #if ($project -is [string]) {
    #    $project = $sln | get-slnprojects | ? { $_.name -eq $project }
    #}
    $slndir = split-path $sln.path -parent
    $r = @()
    
    foreach($p in $projects) {
        $projpath = (gi (join-path $slndir $p.path)).fullname
        $proj = import-csproj $projpath
        $nugetrefs = get-nugetreferences $proj
        $n = $nugetrefs | ? { $_.Name -eq $projectname }
        if ($n -ne $null) { 
            write-verbose "$($p.name) => $projectname [nuget]"
            $r += @{ project = $proj; ref = $pr; type = "nuget"; projectname = $p.name; projectpath = $projpath }
        }
        $projrefs = get-projectreferences $proj
        $pr = $projrefs | ? { $_.Name -eq $projectName }
        if ($pr -ne $null) {
            write-verbose "$($p.name) => $projectname [project]"
            $r += @{ project = $proj; ref = $pr; type = "project"; projectname = $p.name; projectpath = $projpath }
        }
        if ($n -eq $null -and $pr -eq $null) {
            write-verbose "$($p.name) => (none)"
        }
        
    }
    return $r
}

function  convert-projectReferenceToNuget {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)][Sln] $sln, 
        [Alias("project")][Parameter(Mandatory=$true)][string]$projectName, 
        $packagesDir
    )
    
    $projects = $sln | get-slnprojects
    #if ($project -is [string]) {
    #    $project = $sln | get-slnprojects | ? { $_.name -eq $project }
    #}
    $slndir = split-path $sln.path -parent
    $references = get-referencesto $sln $projectname
    
    $csprojs = @()
    
    foreach($r in $references) {
        if ($r.type -ne "project") { continue }
        $pr = $r.ref
        $proj = $r.project
        if ($pr -eq $null) { throw "missing reference in $($r.projectname)" }
        write-verbose "found project reference to $projectname in $($r.projectname)"
        $result += $pr
        $converted = convertto-nuget $pr $packagesDir
        if ($converted -eq $null) { throw "failed to convert referece $pr in project $($r.projectname)" }
        replace-reference $proj $pr $converted
        
        write-verbose "saving modified projet $($r.projectpath)"
        $proj.save($r.projectpath)
        
        $csprojs += get-content $r.projectpath
    }
    
    return $csprojs
}