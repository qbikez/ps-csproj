import-module pathutils
import-module publishmap 

function get-slndependencies {
    param(
        [Parameter(Mandatory=$true)][Sln]$sln
    )
    
    $projects = get-slnprojects $sln | ? { $_.type -eq "csproj" }
    $deps = $projects | % {
        if (test-path $_.fullname) {
            $p = import-csproj $_.fullname
            $refs = @($p | get-projectreferences)
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
                $exists = test-path $path
                $slnrel = get-relativepath (split-path -parent $sln.fullname) $path
                $slnproj = $projects | ? { $_.path -eq $slnrel }
                $existsInSln = $slnproj -ne $null 
                #$null = $r | add-property -name "Valid" -value $existsInSln
                $r.IsValid = $existsInSln
                $props = [ordered]@{ project = $p.project; ref = $r; IsProjectValid = $true }
                $result += new-object -type pscustomobject -property $props 
            }
        } else {
            $isvalid = $true
            if ($p.csproj -eq $null) { $isvalid = $false }
            $props = [ordered]@{ project = $p.project; ref = $null; IsProjectValid = $isvalid }
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
            $missing += new-object -type pscustomobject -property @{ Ref = $d.ref; In = $d.project.fullname  }
        }
        if ($d.isprojectvalid -eq $false) {
            $valid = $false
            $missing += new-object -type pscustomobject -property @{ Ref = $d.project; In = $sln.fullname  }
        }
    }
    
    return $valid,$missing
}