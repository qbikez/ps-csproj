
function get-referencesTo {
        [CmdletBinding(DefaultParameterSetName="sln")]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=0, ParameterSetName="sln")][Sln] $sln,
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=0, ParameterSetName="csproj")][Csproj] $csproj,  
        [Alias("project")][Parameter(Mandatory=$true, Position=1)][string]$projectName
    )
    
    $r = @()
    if ($csproj -ne $null) {
        $proj = $csproj
        $p = $csproj
        $projpath = $proj.fullname        
        #$projpath = (gi ($projpath)).fullname
        
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
            $r += @{ project = $proj; ref = $pr; type = "project"; projectname = $p.name; name = $p.name; projectpath = $projpath }
        }
        if ($n -eq $null -and $pr -eq $null) {
            write-verbose "$($p.name) => (none)"
        }
    } elseif ($sln -ne $null) {
        $projects = $sln | get-slnprojects | ? { $_.type -eq "csproj" }
        $slndir = split-path $sln.path -parent
        foreach($p in $projects) {
            $projpath = join-path $slndir $p.path
            if(!(test-path $projpath)) {
                #write-warning "SLN project $($p.name) not found"
                continue
            }
            $projpath = (gi ($projpath)).fullname
            $proj = import-csproj $projpath
            $r += get-referencesTo $proj $projectname       
        }
    }
    #if ($project -is [string]) {
    #    $project = $sln | get-slnprojects | ? { $_.name -eq $project }
    #}
    
    
    
    
    return $r
}

function convert-projectReferenceToNuget {
    [CmdletBinding(DefaultParameterSetName="referencename",PositionalBinding=$true)]
    param(
        [Parameter(Mandatory=$true)][Csproj] $proj,
        [Parameter(Mandatory=$true, ParameterSetName="referenceObj")][ReferenceMeta] $pr,
        [Parameter(Mandatory=$true, ParameterSetName="referencename")][string] $projectname    
    )    
        if ($pr -eq $null) { throw "missing reference in $($proj.name)" }
        write-verbose "found project reference to $projectname in $($proj.name)"
        
        $result += $pr
        if ((get-command install-package -Module nuget) -ne $null) {
            write-verbose "detected Nuget module. using Nuget/install-package: install-package -ProjectName $($proj.name) -id $($pr.Name)"
            nuget\install-package -ProjectName $proj.name -id $pr.Name
            return "converted with NuGet module"
        }
        else {
            $converted = convertto-nugetreference $pr $packagesDir
            if ($converted -eq $null) { throw "failed to convert referece $pr in project $($proj.name)" }
            $null = replace-reference $proj $pr $converted
            
            write-verbose "saving modified project $($proj.fullname)"
            $null = $proj.save($proj.fullname)
            return $converted 
        }
}

function  convert-ReferencesToNuget {
    [CmdletBinding(DefaultParameterSetName="slnobj")]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, ParameterSetName="slnobj", Position=0)][Sln] $sln, 
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, ParameterSetName="slnfile", Position=0)][string] $slnfile,
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, ParameterSetName="csprojobj", Position=0)][csproj] $csproj, 
        [Alias("project")][Parameter(Mandatory=$true, Position=1)][string]$projectName, 
        [Parameter(Mandatory=$false, Position=2)] $packagesDir = $null
    )
    if (![string]::isnullorempty($slnfile)) {
        $sln = import-sln $slnfile
    }
    
    if ($packagesdir -eq $null) {
        if ($sln -ne $null) { $d = $sln.fullname }
        if ($csproj -ne $null) { $d = $csproj.fullname }
        $packagesdir = find-packagesdir (split-path -parent $d)
    }
    
    $converted = @()
    $csprojs = @()
    
    if ($sln -ne $null)
    {
        $projects = $sln | get-slnprojects
        $slndir = split-path $sln.path -parent
    
    # find all projects that reference $projectName
        $references = get-referencesto $sln $projectname
    }
    elseif ($csproj -ne $null) {
        $references = get-referencesto $csproj $projectname
    }        
        
    foreach($r in $references) {
        if ($r.type -ne "project") { continue }
        $converted = @(convert-projectReferenceToNuget -proj $r.project -pr $r.ref)
        $csprojs += get-content $r.projectpath
        $converted += $converted
    }
        
        
    if ($sln -ne $null) {
        $sln.Save()
        remove-slnproject $sln $projectName -ifexists
    }    
        
    write-verbose "converted $($converted.length) references"
    
    return $converted           
    #return $csprojs
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

new-alias convert-ReferencesToNugets convert-ReferencesToNuget
new-alias tonuget convert-ReferencesToNuget