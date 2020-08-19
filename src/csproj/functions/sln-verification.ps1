import-module pathutils 
import-module publishmap
import-module nupkg


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
                
                $targetFw = ""
                $resolvedPath = ""
                if ($r.type -eq "project") {
                    $r.IsValid = $r.IsValid -and $existsInSln 
                    $targetFw = $p.csproj.TargetFw
                    $resolvedPath = $r.ResolvedPath
                }
                
                
                $version = $null
                if ($r.type -eq "nuget") {
                    if ($r.path -ne $null -and $r.path.replace("\","/") -match "/.*?(?<version>[0-9]+\.[0-9]+\.[0-9]+.*?)/") {                    
                        $version = $Matches["version"]
                    }
                }
                $props = [ordered]@{ project = $p.project; projectTargetFw = $targetFw; ref = $r; refType = $r.type; version = $version;  IsProjectValid = $true; ReslovedPath = $resolvedPath }
                $result += new-object -type pscustomobject -property $props 
            }
        } else {
            $isvalid = $true
            $props = [ordered]@{ project = $p.project; projectTargetFw = ""; ref = $null; refType = $null; version = $null; IsProjectValid = $isvalid; ReslovedPath = ""}
            $result += new-object -type pscustomobject -property $props 
        }
    }
    
    return $result
    
}

function test-sln {
    [CmdletBinding(DefaultParameterSetName = "sln")]
    param(
        [Parameter(Mandatory=$false, ParameterSetName="sln",Position=0)][Sln]$sln,
        [Parameter(Mandatory=$false, ParameterSetName="slnfile",Position=0)][string]$slnfile,
        [switch][bool] $missing,
        [switch][bool] $validate,
        $filter = $null
    )    
    if ($sln -eq $null) {
        if ([string]::IsNullOrEmpty($slnfile)) {
            $slns = @(get-childitem "." -Filter "*.sln")
            if ($slns.Length -eq 1) {
                $slnfile = $slns[0].fullname
            }
            else {
                if ($slns.Length -eq 0) {
                    throw "no sln file given and no *.sln found in current directory"
                }
                else {
                    throw "no sln file given and more than one *.sln file found in current directory"
                }
            }
        }
        if ($slnfile -eq $null) { throw "no sln file given and no *.sln found in current directory" }
        $sln = import-sln $slnfile
    }
    
    
    $deps = get-slndependencies $sln

    if ($filter -ne $null) {
        $deps = $deps | ? {
                if (!($_.ref.ShortName -match $filter)) { write-verbose "$($_.ref.ShortName) does not match filter:$filter" } 
                return $_.ref.ShortName -match $filter 
        }
    }

    $missingdeps = @($deps | ? { $_.IsProjectValid -eq $false -or ($_.ref -ne $null -and $_.ref.IsValid -eq $false) })
    if ($missing) {        
        return $missingdeps
    }
    if ($validate) {
        return $missingdeps.length -eq 0
    }
    
    return $deps
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


function find-reporoot($path = ".") {
        $found = find-upwards ".git",".hg" -path $path
        if ($found -ne $null) { return split-path -Parent $found }
        else { return $null } 
}

function find-globaljson($path = ".") {
    return find-upwards "global.json" -path $path    
}


function find-matchingprojects {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]$missing,
        [Parameter(Mandatory=$true)]$reporoot
        )
    if (test-path (join-path $reporoot ".projects.json")) {
        $script:projects = get-content (join-path $reporoot ".projects.json") | out-string | convertfrom-jsonnewtonsoft 
        write-verbose "getting csproj from cached file .projects.json"
        $csprojs = $script:projects.GetEnumerator() | ? {
                #ignore non-existing projects from ".projects.json" 
                test-path (join-path $reporoot $_.value.path) 
        } | % {
            get-item (join-path $reporoot $_.value.path)
        }
    } else { 
        $csprojs = get-childitem "$reporoot" -Filter "*.csproj" -Recurse
    }
    #$csprojs | select -expandproperty name | format-table | out-string | write-verbose
    $packagesdir = find-packagesdir $reporoot
    write-verbose "found $($csprojs.length) csproj files in repo root '$reporoot' and subdirs. pwd='$(pwd)'. Packagesdir = '$packagesdir'"
    $missing = $missing | % {
        $m = $_
        $matching = $null
        if ($m.ref.type -eq "project" -or $m.ref.type -eq "csproj") {
            $matching = @($csprojs | ? { [System.io.path]::GetFilenameWithoutExtension($_.Name) -eq $m.ref.Name })
            $null = $m | add-property -name "matching" -value $matching
            #write-verbose "missing: $_.Name matching: $matching"
        }
        if ($m.ref.type -eq "nuget") {
            if ($m.ref.path -match "^(?<packages>.*packages[/\\])(?<pkg>.*)") {
                $matchingpath = join-path $packagesdir $matches["pkg"]
                if (test-path $matchingpath) {
                    $matching = get-item $matchingpath
                } else {
                    $matching = new-object -type pscustomobject -property @{
                        fullname = $matchingpath
                    }
                }
                $null = $m | add-property -name "matching" -value $matching
                #write-verbose "missing: $_.Name matching: $matching"
            }
        }
        if ($matching -eq $null) {
            write-verbose "no project did match '$($m.ref.Name)' reference of type $($m.ref.type)"
        } else {
            write-verbose "found  $(@($matching).Length) matching projects for '$($m.ref.Name)' reference of type $($m.ref.type):"
            $matching | % {
                write-verbose "    $($_.fullname)"
            }
        }
        
        
        return $m
    }
    
    
    
    
    return $missing
}


function repair-slnpaths {
    [CmdletBinding(DefaultParameterSetName = "sln")]
    param(
        [Parameter(Mandatory=$false, ParameterSetName="sln",Position=0)][Sln]$sln,
        [Parameter(Mandatory=$false, ParameterSetName="slnfile",Position=0)][string]$slnfile,
        [Parameter(Position=1)] $reporoot,
        [Parameter(Position=2)] $filter = $null,
        [switch][bool] $tonuget,
        [switch][bool] $insln,
        [switch][bool] $incsproj,
        [switch][bool] $removemissing,
        [switch][bool] $prerelease
    )
     if ($sln -eq $null) {
        if ([string]::IsNullOrEmpty($slnfile)) {
            $slns = @(get-childitem "." -Filter "*.sln")
            if ($slns.Length -eq 1) {
                $slnfile = $slns[0].fullname
            }
            else {
                if ($slns.Length -eq 0) {
                    throw "no sln file given and no *.sln found in current directory"
                }
                else {
                    throw "no sln file given and more than one *.sln file found in current directory"
                }
            }
        }
        if ($slnfile -eq $null) { throw "no sln file given and no *.sln found in current directory" }
        $sln = import-sln $slnfile
    }
   
    if (!$incsproj.IsPresent -and !$insln.ispresent) {
        $incsproj = $true
        $insln = $true
    }

  
    if ($insln) {
        $valid,$missing = test-slndependencies $sln 
        
        write-verbose "SLN: found $($missing.length) missing projects"
        if ($reporoot -eq $null) {
            $reporoot = find-reporoot $sln.fullname
            if ($reporoot -ne $null) {
                write-host "auto-detected repo root at $reporoot"
            }
        }
        
        if ($reporoot -eq $null) {
            throw "No repository root given and none could be detected"
        }

        write-host "Fixing SLN..."
        
        write-verbose "looking for csprojs in reporoot..."
        $missing = find-matchingprojects $missing $reporoot
        if ($filter -ne $null) {
        $missing = $missing | ? {
                #if (!($_.ref.ShortName -match $filter)) { write-verbose "$($_.ref.ShortName) does not match filter:$filter" } 
                return $_.ref.ShortName -match $filter 
        }
    }

        

        $fixed = @{}

        foreach($_ in $missing) {
            if ($fixed.ContainsKey($_.ref.name)) {
                write-verbose "skipping fixed reference $($_.ref.name)"
                continue
            }
            if ($_.ref.Type -ne "project" -and $_.ref.Type -ne "csproj") {
                write-verbose "skipping non-project reference  '$($_.ref.name)' of type '$($_.ref.type)'"
                continue
            }
            write-verbose "trying to fix missing SLN reference '$($_.ref.name)'"
            if ($_.matching -eq $null -or $_.matching.length -eq 0) {
                write-warning "no matching project found for SLN item $($_.ref.name)"
                if ($removemissing) {
                    write-warning "removing $($_.ref.Path)"
                    remove-slnproject $sln $($_.ref.Name) -ifexists
                    $sln.Save()
                }
            }
            else {
                $matching = $_.matching
                if (@($matching).length -gt 1) {
                    write-host "found $($matching.length) matching projects for $($_.ref.name). Choose one:"
                    $i = 1
                    $matching = $matching | sort FullName                                        
                    $matching | % {
                        write-host "  $i. $($_.fullname)"
                        $i++
                    }
                    $c = read-host 
                    $matching = $matching[[int]$c-1]
                }
                if ($_.ref -is [slnproject]) {
                    $relpath = get-relativepath $sln.fullname  $matching.fullname
                    write-host "Fixing bad SLN reference: $($_.ref.Path) => $relpath"
                    $_.ref.Path = $relpath
                    update-slnproject $sln $_.ref
                    $fixed[$_.ref.name] = $true
                }
                elseif ($_.ref -isnot [referencemeta]) {
                    $relpath = get-relativepath $sln.fullname  $matching.fullname
                    write-host "Adding missing SLN reference:  $($_.ref.Path) => $relpath"
                    $csp = import-csproj  $matching.fullname
                    add-slnproject $sln -name $csp.Name -path $relpath -projectguid $csp.guid
                    $fixed[$_.ref.name] = $true
                } else {
                    $relpath = get-relativepath $sln.fullname  $matching.fullname
                    write-host "Adding missing SLN reference:  $($_.ref.Path) => $relpath"
                    $csp = import-csproj  $matching.fullname
                    add-slnproject $sln -name $csp.Name -path $relpath -projectguid $csp.guid
                    $fixed[$_.ref.name] = $true
                    #write-warning "Don't know what to do with $($_.ref) of type $($_.ref.GetType())"
                }
            }
        }
        
       
        write-host "saving sln"
        $sln.Save()
    }
    if ($incsproj) {
        write-host "Fixing CSPROJs..."

        $projects = get-slnprojects $sln | ? { $_.type -eq "csproj" }
    
         if ($tonuget) {
            $pkgdir =(find-packagesdir $reporoot)
            write-verbose "packages dir found at: '$pkgdir'"
            if (!(test-path $pkgdir)) {
                $null = new-item -type Directory $pkgdir
            }
            $missing = test-sln $sln -missing 
            $missing = @($missing | ? { $_.ref.type -eq "project"})
            $missing = $missing | % { $_.ref.name } | sort -Unique
        
            $missing | % {
                try {
                    write-host "replacing $_ with nuget"
                    $found = find-nugetPath $_ $pkgdir 
                    if ($found -eq $null) {
                        write-host "installing package $_"
                    nuget install $_ -out $pkgdir -pre
                    }                    
                    convert-referencestonuget $sln -projectName $_ -packagesDir $pkgdir -filter $filer
                } catch {
                    write-error $_
                }
            }
        }
    
        foreach($_ in $projects) {
            if (test-path $_.fullname) {
                $csproj = import-csproj $_.fullname
            
                if (!$tonuget) {
                    $null = repair-csprojpaths $csproj -reporoot $reporoot -prerelease:$prerelease 
                }            
            }
        }
    }
    
#    $valid,$missing = test-slndependencies $sln
#    $valid | Should -Be $true
    
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
        $props = [ordered]@{ projectTargetFw = $csproj.TargetFw; ref = $r; refType = $r.type; path = $r.path; targetFw = $r.TargetFw }
        return new-object -type pscustomobject -property $props 
    }
    
    return $refs
}


function repair-csprojpaths {
     [CmdletBinding(DefaultParameterSetName = "csproj")]
    param(
        [Parameter(Mandatory=$true, ParameterSetName="csproj",Position=0)][Csproj]$csproj,
        [Parameter(Mandatory=$true, ParameterSetName="csprojfile",Position=0)][string]$csprojfile,
        $reporoot = $null,
        [switch][bool] $prerelease
    )
    if ($csproj -eq $null) { $csproj = import-csproj $csprojfile }
  
    $deps = get-csprojdependencies $csproj
    $missing = @($deps | ? { $_.ref.IsValid -eq $false })
     
    write-verbose "($($csproj.name)): CSPROJ found $($missing.length) missing projects"
    if ($reporoot -eq $null) {
        $reporoot = find-reporoot $csproj.fullname
        if ($reporoot -ne $null) {
            write-verbose "($($csproj.name)): auto-detected repo root at $reporoot"
        }
    }
    
    if ($reporoot -eq $null) {
        throw "($($csproj.name)): No repository root given and none could be detected"
    }

    if ($missing.length -gt 0) {
        write-verbose "($($csproj.name)): looking for projects matching missing references"
        $missing = find-matchingprojects $missing $reporoot
    
        $missing | % {
            if ($_.matching -eq $null -or $_.matching.length -eq 0) {
                write-warning "($($csproj.name)): no matching project found for CSPROJ reference $($_.ref.Path)"
            }
            else {
                $relpath = get-relativepath $csproj.fullname $_.matching.fullname
            
                $oldPath = $_.ref.Path
                $_.ref.Path = $relpath
                if ($_.ref.type -eq "project" -and $_.ref.Node.Include -ne $null) {
                    write-verbose "($($csproj.name)): fixing CSPROJ reference in $($csproj.name): $oldPath => $relpath"
                    $_.ref.Node.Include = $relpath
                } 
                if ($_.ref.type -eq "nuget" -and $_.ref.Node.HintPath -ne $null) {
                    write-verbose "($($csproj.name)): fixing NUGET reference in $($csproj.name): $oldPath => $relpath"
                    $_.ref.Node.HintPath = $relpath
                }
            }

        }
        $csproj.Save()
        write-verbose "($($csproj.name)): missing references done"
    }
   
    $pkgdir = find-packagesdir $reporoot
    write-verbose "packages dir found at '$pkgdir'"
    $dir = split-path -parent $csproj.FullName
    if (test-path (Join-Path $dir "packages.config")) {
        write-verbose "($($csproj.name)): checking packages.config"
        $pkgs_cfg = get-packagesconfig (Join-Path $dir "packages.config") 
        $pkgs = $pkgs_cfg.packages
        $isInsideVS = (get-command "install-package" -Module nuget -errorAction Ignore) -ne $null 
        if ($isInsideVS) {
            write-verbose "($($csproj.name)): detected Nuget module. using Nuget/install-package"
            foreach($dep in $pkgs) {
                nuget\install-package -ProjectName $csproj.name -id $dep.id -version $dep.version -prerelease:$prerelease
            }
        } else {
            $refs = get-nugetreferences $csproj 
            foreach($pkgref in $pkgs) {
                $ref = $refs | ? { $_.ShortName -eq $pkgref.id }
                if ($ref -eq $null) {                    
                    $nugetpath = find-nugetpath $pkgref.id $pkgdir -versionhint $pkgref.version
                    if ($nugetpath -ne $null) {
                        $dllname = [System.IO.Path]::GetFileNameWithoutExtension($nugetpath.PAth)
                        $ref = $refs | ? { $_.ShortName -eq $dllname }
                        if ($ref -ne $null) {
                            write-verbose "$($pkgref.id) maps to $($nugetpath.PAth)"
                        }
                    }
                    if ($ref -eq $null) {
                        write-warning "($($csproj.name)): missing csproj reference for package $($pkgref.id)"
                    }
                }
                if ($ref.path -notmatch "$($pkgref.version)\\") {
                    # bad reference in csproj? try to detect current version
                    if ($ref.path -match "$($pkgref.id).(?<version>.*?)\\") {
                        Write-Warning "($($csproj.name)): version of package '$($pkgref.id)' in csproj: '$($matches["version"])' doesn't match packages.config version: '$($pkgref.version)'. Fixing"
                        # fix it
                        # use latest version
                        $csproj_ver = split-version $matches["version"]
                        $packages_ver = split-version $pkgref.version
                        if (($packages_ver.CompareTo($csproj_ver)) -gt 0) {
                            write-verbose "correcting csproj` to use version $packages_Ver"
                            $ref.path = $ref.path -replace "$($pkgref.id).(?<version>.*?)\\","$($pkgref.id).$($pkgref.version)\"
                            write-verbose "corrected path: $($ref.path)"
                            $ref.Node.HintPath = $ref.path
                            $inc = $ref.Node.Include
                            if ($inc -ne $null -and $inc -match "$($pkgref.id),\s*Version=(.*?),") {
                                write-verbose "($($csproj.name)): fixing include tag"
                                $inc = $inc -replace "($($pkgref.id)),\s*Version=(.*?),",'$1,'
                                write-verbose "corrected include: $($ref.path)"
                                $ref.Node.Include = $inc
                            }
                            $csproj.save()
                        }
                        else {
                            write-verbose "correcting packages.config to use version $csproj_ver"
                            $pkgref.version = $csproj_ver.ToString()
                            set-packagesconfig -pkgconfig $pkgs_cfg -outfile (Join-Path $dir "packages.config") 
                        }
                    }
                }
            }
            
        }
    }
    
#    $valid,$missing = test-slndependencies $sln
#    $valid | Should -Be $true
    
}

function update-nuget {
    param([Parameter(mandatory=$true,ValueFromPipeline=$true)]$id, $version) 

process {
    write-verbose "checking packages.config"
    $pkgconfig = get-packagesconfig ("packages.config") 
    $pkgs = $pkgconfig.packages
    $changed = $false
    foreach($pkgid in @($id)) {
        $ver = $version
        if ($pkgid -match "(?<id>.*)\.(?<version>[0-9]+\.[0-9]+\.[0-9]+.*)") {
                $ver = $matches["version"]
                $pkgid = $matches["id"]
        }
        else {
            write-warning "please specify package version with -version or in package id (like '$pkgid.1.0.0')"
            continue
        }
        if ($ver -eq $null) {            
            
        }

        $ref = $pkgs | ? { $_.id -eq $pkgid }

        if ($ref -ne $null) {
            $changed = $true
            $ref.version = $ver
        } else {
            write-warning "package $pkgid not found in packages.config"
            continue
        }
    }

    if ($changed) {
        $pkgconfig | set-packagesconfig -outfile "packages.config"
        get-childitem . -filter "*.csproj" | %{
            fix-csproj $_.FullName
        }
    }
}
}



new-alias fix-sln repair-slnpaths -Force
new-alias fixsln fix-sln -Force
new-alias fix-csproj repair-csprojpaths -Force
new-alias fixcsproj fix-csproj -Force