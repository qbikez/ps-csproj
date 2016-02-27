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
            $r += @{ project = $proj; ref = $n; type = "nuget"; projectname = $p.name; name = $p.name; projectpath = $projpath }
        }
        $projrefs = get-projectreferences $proj
        $pr = $projrefs | ? { $_.Name -eq $projectName }
        if ($pr -ne $null) {
            write-verbose "$($p.name) => $projectname [project]"
            $r += @{ project = $proj; ref = $pr; type = "project"; projectname = $p.name; name = $p.name;projectpath = $projpath }
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
    
    $packagesdir = Get-RelativePath $slndir $packagesDir
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

function convert-nugetToProjectReference {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact="high")]
    param([Parameter(Mandatory=$false)] $referencename, [Parameter(Mandatory=$false)] $targetProject, [Parameter(Mandatory=$false)] $csproj) 
        $path = $csproj
        
        if ($path -eq $null) {
            $items = @(get-childitem -filter "*.csproj")
            if ($items -eq $null -or $items.length -eq 0) {
                throw "no csproj given and no csproj found in current dir"
            }
            if ($items.length -ne $null -and $items.length -gt 1) {
                throw "more than one csproj file found. please select one"
            } 
            $path = $items.fullname
        }
        
        $csproj = import-csproj $path
        $refs = ($csproj | get-externalreferences) + ($csproj | get-nugetreferences)
        
        if ($referenceName -eq $null){
            write-host "Choose one reference:"
            $refs | select -expand ShortName
            return
        }
        
        if ($targetproject -eq $null) {
            write-host "please provide target project location"
            return
        } 
        $r = $refs | ? { $_.shortname -eq $referencename }
        $converted = convertto-projectreference $r $targetProject
        
        replace-reference $csproj $r $converted
        
        if ($pscmdlet.ShouldProcess("saving csproj $path")) {
            $csproj.Save()
        }
}