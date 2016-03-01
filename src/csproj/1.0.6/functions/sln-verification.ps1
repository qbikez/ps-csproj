import-module pathutils
import-module publishmap 

function get-slndependencies {
    param(
        [Parameter(Mandatory=$true)][Sln]$sln
    )
    
    $projects = get-slnprojects $sln | ? { $_.type -eq "csproj" }
    $deps = $projects | % {
        $p = import-csproj $_.fullname
        $refs = @($p | get-projectreferences)
        return new-object -type pscustomobject -property @{ project = $_; csproj = $p; refs = $refs; }
    }
    
    $result = @()
    foreach($p in $deps) {
        if ($p.refs.length -gt 0) {
            foreach($r in $p.refs) {
                $path = $r.path
                $path = join-path (split-path -parent $p.project.fullname) $r.path
                $exists = test-path $path
                $slnrel = get-relativepath (split-path -parent $sln.fullname) $path
                $slnproj = $projects | ? { $_.path -eq $slnrel }
                $existsInSln = $slnproj -ne $null 
                #$null = $r | add-property -name "Valid" -value $existsInSln
                $r.IsValid = $existsInSln
                $props = [ordered]@{ project = $p.project; ref = $r }
                $result += new-object -type pscustomobject -property $props 
            }
        } else {
                $props = [ordered]@{ project = $p.project; ref = $null }
                $result += new-object -type pscustomobject -property $props 
        }
    }
    
    return $result
    
}

function test-slndependencies {
    param(
        [Parameter(Mandatory=$true)][Sln]$sln
    )
 
    $deps = get-slndependencies $sln
    
    $valid = $true
    $missing = @()
    
    foreach($d in $deps) {
        if ($d.ref -ne $null -and $d.ref.IsValid -eq $false) {
            $valid = $false
            $missing += $d.ref
        }
    }
    
    return $valid,$missing
}