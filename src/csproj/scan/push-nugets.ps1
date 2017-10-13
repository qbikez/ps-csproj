import-module newtonsoft.json

function Push-Nugets {
[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [switch][bool] $scan,
    [switch][bool] $all,
    [switch][bool] $AllowNoNuspec,
    [switch][bool] $force    
)


DynamicParam
{
    $paramDictionary = new-object -Type System.Management.Automation.RuntimeDefinedParameterDictionary
    
    if ($true -or (test-path ".projects.json")) {
        $paramname = "Project"
        $paramType = [string[]]

        $attributes = new-object System.Management.Automation.ParameterAttribute
        $attributes.ParameterSetName = "__AllParameterSets"
        $attributes.Mandatory = $false
        #$attributes.Position = 0
        $attributeCollection = new-object -Type System.Collections.ObjectModel.Collection[System.Attribute]
        $attributeCollection.Add($attributes)

         if ((test-path ".projects.json")) {
            $script:projects = get-content ".projects.json" | out-string | convertfrom-jsonnewtonsoft 
            $validvalues = $projects.Keys
            $validvalues += "*"
            $validateset = new-object System.Management.Automation.ValidateSetAttribute -ArgumentList @($validvalues)
            $attributeCollection.Add($validateset)
        }
        
        $dynParam1 = new-object -Type System.Management.Automation.RuntimeDefinedParameter($paramname, $paramType, $attributeCollection)

        
        $paramDictionary.Add($paramname, $dynParam1)
    }
    
    $c = get-command "push-nuget"
    $cmdlet = $pscmdlet
    foreach($p in $c.Parameters.GetEnumerator()) {
        if ($p.Key -in [System.Management.Automation.PSCmdlet]::OptionalCommonParameters -or `
            $p.Key -in [System.Management.Automation.PSCmdlet]::CommonParameters) { 
            continue 
        }
        $dynParam1 = new-object -Type System.Management.Automation.RuntimeDefinedParameter($p.Key, $p.Value.ParameterType, $p.Value.Attributes)
        
        $paramDictionary.Add($p.key, $dynParam1)
    }

    return $paramDictionary
}
begin {
    function filter-BoundParameters($cmd, $bound) {
        $c = get-command $cmd
        $cmdlet = $pscmdlet
        if ($bound -eq $null) {
            $bound = $cmdlet.MyInvocation.BoundParameters
        }
        $r = @{}
        foreach($p in $c.Parameters.GetEnumerator()) {
            if ($p.key -in $bound.Keys) {
                $r += @{ $p.key = $bound[$p.key] }
            }
        }

        return $r   
    }
}
process {
    if ($scan -or !(test-path ".projects.json")) {
        scan-projects
        if ($scan) { return }
    }

    $b = $cmdlet.MyInvocation.BoundParameters
    $project =  $PSBoundParameters["Project"]

    function push-project($project) {
        $path = $project.path
        if ($project.hasNuspec -ne "true" -and !$force -and !$AllowNoNuspec) {
            write-host "skipping project '$($project.name)' with no nuspec. use -AllowNoNuspec to override"
            continue
        }
        if ($project.path.startswith("test\")) { 
            write-host "skipping TEST project '$($project.name)'"
            continue
        }
        
        $p = filter-BoundParameters "push-nuget" -bound $b
        return push-nuget @p
        
    }

    $a = @{
        AllowNoNuspec = ($AllowNoNuspec -or $force)
    }
    if ($project -ne $null) {
        $a += @{
            project = $project
        }
    }


    foreach-project @a -cmd { 
        try {
            push-project $_
        } catch {
            #Write-Error "$($_.Exception.Message) $($_.ScriptStackTrace)"
            #throw
            throw "$($_.Exception.Message) $($_.ScriptStackTrace)"
        } 
    }   
}
}


function update-referencesToStable {
    [CmdletBinding(DefaultParameterSetName="packages")]
    param(
        [Parameter(Mandatory=$true,ParameterSetName="packages")]$packages,
        [Parameter(Mandatory=$true,ParameterSetName="singlePackage")]$package,
        [Parameter(Mandatory=$false,ParameterSetName="singlePackage")]$version
        )

    foreach-project -AllowNoNuspec $true -cmd {
        try {
            
            # $pwd
            # $_.path
            # $_.name
            if (!$_.path.EndsWith(".csproj")) { return }
            $pkgcfg = import-packagesconfig "packages.config"
            $csproj = import-csproj (split-path -leaf $_.path)
            
            $pkgs = $pkgcfg.packages
            $refs = get-nugetreferences $csproj 
            if ($packages -eq $null -and $package -ne $null) {
                $packages = @(@{ Id=$package; Version=$version})
            }
            $packages = @($packages) | % { 
                $id =  $_.Id
                if ($id -eq $null) {$id = $_ }
                $version = $_.version
                return new-object pscustomobject -property @{ Id = $id; Version = $version }
            }            
            $packages = @($packages)
            #write-verbose "looking for packagesnames: $($packages)" -verbose
            #TODO: compare nuspec files for current unstable version and new stable version - make sure dependencies haven't change 
            $pkgs = @($pkgs | ? {$_.id -in $packages.Id })

            if ($pkgs.count -gt 0) {
                write-verbose "found $($pkgs.count) matching package refernces in project '$($_.name)'" -verbose
                foreach($pkgref in $pkgs) {
                    $oldver = $pkgref.Version
                    $newpackage = $packages | ? { $_.Id -eq $pkgref.Id }
                    if ($newpackage -eq $null) { throw "'$($pkgref.Id)' not found in packages list" }
                    $ver = $newpackage.Version 
                    if ($ver -eq $null) {
                        $ver = $pkgref.Version
                        write-verbose "no version specified for package '$($pkgref.Id)'. just convert to stable from '$ver'" -Verbose
                        
                        $idx = $ver.indexof("-")
                        if ($idx -ge 0) {
                            $ver = $ver.substring(0, $idx)                            
                        }
                    }

                    if ($oldver -ne $ver) {
                        write-verbose "updating package $($pkgref.id) version $oldver => $ver" -verbose
                        $pkgref.version = $ver
                        $pkgcfg | set-packagesconfig -outfile "packages.config"
                    }
                    write-output (new-object pscustomobject -property @{ Id=$pkgref.id; Version=$ver })
                    $ref = $refs | ? { $_.ShortName -eq $pkgref.id }
                    if ($ref.path -notmatch "$($pkgref.version)\\") {
                        # bad reference in csproj? try to detect current version
                        if ($ref.path -match "$($pkgref.id).(?<version>.*?)\\") {
                            Write-Warning "($($csproj.name)): version of package '$($pkgref.id)' in csproj: '$($matches["version"])' doesn't match packages.config version: '$($pkgref.version)'. Fixing"
                            # fix it
                            $ref.path = $ref.path -replace "$($pkgref.id).(?<version>.*?)\\","$($pkgref.id).$($pkgref.version)\"
                            write-verbose "corrected path: $($ref.path)" -verbose
                            $ref.Node.HintPath = $ref.path
                            $inc = $ref.Node.Include
                            if ($inc -ne $null -and $inc -match "$($pkgref.id),\s*Version=(.*?),") {
                                write-verbose "($($csproj.name)): fixing include tag" -verbose
                                $inc = $inc -replace "($($pkgref.id)),\s*Version=(.*?),",'$1,'
                                write-verbose "corrected include: $($ref.path)" -verbose
                                $ref.Node.Include = $inc
                            }
                            $csproj.save()
                        }
                    } else {
                        write-verbose "$($ref.path) matches version $($pkgref.version)"
                    }
                }
            }
        } catch {
            write-error $_
            write-error $_.scriptstacktrace
        }
    }
}

new-alias Update-PackageReferencesToStable update-referencesToStable
new-alias Update-PackagesToStable update-referencesToStable