import-module pathutils
import-module publishmap 

function get-slndependencies {
    [CmdletBinding(DefaultParameterSetName = "sln")]
    param(
        [Parameter(Mandatory=$true, ParameterSetName="sln",Position=0)][Sln]$sln,
        [Parameter(Mandatory=$true, ParameterSetName="slnfile",Position=0)][string]$slnfile
    )
    if ($sln -eq $null) { $sln = import-sln $slnfile }
    $projects = get-slnprojects $sln | ? { $_.type -eq "csproj" }
    $deps = $projects | % {
        if (test-path $_.fullname) {
            $p = import-csproj $_.fullname
            $refs = @()
            $refs += @($p | get-projectreferences)
            $refs += @($p | get-nugetreferences)
            
        } else {
            $p = $null
            $refs = $null
        }
        return new-object -type pscustomobject -property @{ project = $_; csproj = $p; refs = $refs }
    }
    
    $result = @()
    foreach($p in $deps) {
        
        if ($p.refs -ne $null -and $p.refs.length -gt 0) {
            foreach($r in $p.refs) {
                $path = $r.path
                $path = join-path (split-path -parent $p.project.fullname) $r.path
                $slnrel = get-relativepath (split-path -parent $sln.fullname) $path
                $slnproj = $projects | ? { $_.path -eq $slnrel }
                $existsInSln = $slnproj -ne $null 
                $exists = test-path $path
                #$null = $r | add-property -name "Valid" -value $existsInSln
                if ($r.type -eq "project") {
                    $r.IsValid = $r.IsValid -and $existsInSln 
                }
                $props = [ordered]@{ project = $p.project; ref = $r; refType = $r.type; IsProjectValid = $true }
                $result += new-object -type pscustomobject -property $props 
            }
        } else {
            $isvalid = $true
            if ($p.csproj -eq $null) { $isvalid = $false }
            $props = [ordered]@{ project = $p.project; ref = $null; refType = $null; IsProjectValid = $isvalid }
            $result += new-object -type pscustomobject -property $props 
        }
    }
    
    return $result
    
}

function test-slndependencies {
     [CmdletBinding(DefaultParameterSetName = "sln")]
    param(
        [Parameter(Mandatory=$true, ParameterSetName="sln",Position=0)][Sln]$sln,
        [Parameter(Mandatory=$true, ParameterSetName="slnfile",Position=0)][string]$slnfile
    )
    if ($sln -eq $null) { $sln = import-sln $slnfile }
  
   $deps = get-slndependencies $sln
    
    $valid = $true
    $missing = @()
    
    foreach($d in $deps) {
        if ($d.ref -ne $null -and $d.ref.IsValid -eq $false) {
            $valid = $false
            $missing += new-object -type pscustomobject -property @{ Ref = $d.ref; In = $d.project.fullname  }
        }
        if ($d.isprojectvalid -eq $false) {
            $valid = $false
            $missing += new-object -type pscustomobject -property @{ Ref = $d.project; In = $sln.fullname  }
        }
    }
    
    return $valid,$missing
}

function find-reporoot($path) {
        if (!(get-item $path).IsPsContainer) {
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
        return $reporoot
}

function find-matchingprojects {
    param (
        [Parameter(Mandatory=$true)]$missing,
        [Parameter(Mandatory=$true)]$reporoot
        )
    $csprojs = get-childitem "$reporoot" -Filter "*.csproj" -Recurse
    $missing = $missing | % {
        $m = $_
        $matching = @($csprojs | ? { [System.io.path]::GetFilenameWithoutExtension($_.Name) -eq $m.ref.Name })
        $null = $m | add-property -name "matching" -value $matching
        #write-verbose "missing: $_.Name matching: $matching"
        return $m
    }
    
    return $missing
}


function repair-slnpaths {
    [CmdletBinding(DefaultParameterSetName = "sln")]
    param(
        [Parameter(Mandatory=$true, ParameterSetName="sln",Position=0)][Sln]$sln,
        [Parameter(Mandatory=$true, ParameterSetName="slnfile",Position=0)][string]$slnfile,
        [Parameter(Position=1)] $reporoot
    )
    if ($sln -eq $null) { $sln = import-sln $slnfile }
  
    $valid,$missing = test-slndependencies $sln
     
    write-verbose "found $($missing.length) missing projects"
    if ($reporoot -eq $null) {
        $reporoot = find-reporoot $sln.fullname
        if ($reporoot -ne $null) {
            write-verbose "auto-detected repo root at $reporoot"
        }
    }
    
    if ($reporoot -eq $null) {
        throw "No repository root given and none could be detected"
    }

    $missing = find-matchingprojects $missing $reporoot
    
    $missing | % {
        $relpath = get-relativepath $sln.fullname $_.matching.fullname
        write-verbose "fixing reference: $($_.ref.Path) => $relpath"
        $_.ref.Path = $relpath
        
        update-slnproject $sln $_.ref
    }
    
    $sln.Save()
    
#    $valid,$missing = test-slndependencies $sln
#    $valid | Should Be $true
    
}


function get-csprojdependencies {
     [CmdletBinding(DefaultParameterSetName = "csproj")]
    param(
        [Parameter(Mandatory=$true, ParameterSetName="csproj",Position=0)][Csproj]$csproj,
        [Parameter(Mandatory=$true, ParameterSetName="csprojfile",Position=0)][string]$csprojfile
    )

    if ($csproj -eq $null) { $csproj = import-csproj $csprojfile }
   
    $refs = @()
    $refs += get-projectreferences $csproj
    $refs += get-nugetreferences $csproj
    
    $refs = $refs | % {
        $r = $_
        $props = [ordered]@{ ref = $r; refType = $r.type; path = $r.path }
        return new-object -type pscustomobject -property $props 
    }
    
    return $refs
}


function repair-csprojpaths {
     [CmdletBinding(DefaultParameterSetName = "csproj")]
    param(
        [Parameter(Mandatory=$true, ParameterSetName="csproj",Position=0)][Csproj]$csproj,
        [Parameter(Mandatory=$true, ParameterSetName="csprojfile",Position=0)][string]$csprojfile,
        $reporoot = $null
    )
    if ($csproj -eq $null) { $csproj = import-csproj $csprojfile }
  
    $deps = get-csprojdependencies $csproj
    $missing = @($deps | ? { $_.ref.IsValid -eq $false })
     
    write-verbose "found $($missing.length) missing projects"
    if ($reporoot -eq $null) {
        $reporoot = find-reporoot $csproj.fullname
        if ($reporoot -ne $null) {
            write-verbose "auto-detected repo root at $reporoot"
        }
    }
    
    if ($reporoot -eq $null) {
        throw "No repository root given and none could be detected"
    }

    $missing = find-matchingprojects $missing $reporoot
    
    $missing | % {
        $relpath = get-relativepath $csproj.fullname $_.matching.fullname
        write-verbose "fixing reference: $($_.ref.Path) => $relpath"
        $_.ref.Path = $relpath
        if ($_.ref.Node.Include -ne $null) {
            $_.ref.Node.Include = $relpath
        } 

        #TODO: update csproj with fixed references
    }
    
    $csproj.Save()
    
#    $valid,$missing = test-slndependencies $sln
#    $valid | Should Be $true
    
}


new-alias fix-sln repair-slnpaths
new-alias fixsln fix-sln
new-alias fix-csproj repair-csprojpaths
new-alias fixcsproj fix-csproj 