function Use-Projects {
[CmdletBinding()]
param(
    [switch][bool] $scan,
    [switch][bool] $all,
    [switch][bool] $AllowNoNuspec = $true,
    [switch][bool] $force,
    [Parameter(Mandatory=$true)]
    [ScriptBlock] $cmd
)


DynamicParam
{
    $paramDictionary = new-object -Type System.Management.Automation.RuntimeDefinedParameterDictionary
    
    if ($true -or (test-path ".projects")) {
        $paramname = "Project"
        $paramType = [string[]]

        $attributes = new-object System.Management.Automation.ParameterAttribute
        $attributes.ParameterSetName = "__AllParameterSets"
        $attributes.Mandatory = $false
        #$attributes.Position = 0
        $attributeCollection = new-object -Type System.Collections.ObjectModel.Collection[System.Attribute]
        $attributeCollection.Add($attributes)

        $script:projects = get-content ".projects.json" | out-string | convertfrom-jsonnewtonsoft 

        $validvalues = $projects.Keys

        $validateset = new-object System.Management.Automation.ValidateSetAttribute -ArgumentList @($validvalues)
        $attributeCollection.Add($validateset)
        $dynParam1 = new-object -Type System.Management.Automation.RuntimeDefinedParameter($paramname, $paramType, $attributeCollection)

        
        $paramDictionary.Add($paramname, $dynParam1)
    }
    import-module nupkg
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
    function filter-BoundParameters($cmd) {
        $c = get-command $cmd
        $cmdlet = $pscmdlet
        $bound = $cmdlet.MyInvocation.BoundParameters
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
        return 
    }

    ipmo nupkg

    $project =  $PSBoundParameters["Project"]
    if ($script:projects -eq $null) { $projects = get-content ".projects.json" | out-string | convertfrom-jsonnewtonsoft  }
    
    if ($all) {
        $project = $projects.Keys
    } 
    elseif ($project -eq $null) {
        $project = $projects.Keys
        $project = $project | ? { $projects[$_].hasNuspec -eq "true" }
    }
    #. ./pack-nugets.ps1 -Filter $Filter
    
    function push-project($project) {
        $path = $projects[$project].path
        if ($projects[$project].hasNuspec -ne "true" -and !$force -and !$AllowNoNuspec) {
            write-host "skipping project '$project' with no nuspec"
            continue
        }
        pushd 
        try {
            cd (split-path -parent $path)
            $p = filter-BoundParameters "push-nuget"
            $o = Invoke-Command $cmd
            return $o
        } 
        catch {
            write-error $_
            return $_
        }
        finally {
            popd
        }
    }

    $r = @{}

    foreach($p in @($project)) {
        $r += @{ $p = (push-project $p) }
    }

    $r
}
}

new-alias Foreach-Project Use-Projects