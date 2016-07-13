function Push-Nugets {
[CmdletBinding()]
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
        return 
    }

    $b = $cmdlet.MyInvocation.BoundParameters
    $project =  $PSBoundParameters["Project"]

    function push-project($project) {
        $path = $project.path
        if ($project.hasNuspec -ne "true" -and !$force -and !$AllowNoNuspec) {
            write-host "skipping project '$($project.name)' with no nuspec"
            continue
        }
        if ($project.path.startswith("test\")) { 
            write-host "skipping TEST project '$($project.name)'"
            continue
        }
        try {
            $p = filter-BoundParameters "push-nuget" -bound $b
            return push-nuget @p
        } 
        catch {
            write-error $_
            return $_
        }
    }

    foreach-project -project:$project -AllowNoNuspec:($AllowNoNuspec -or $force) -cmd { 
        push-project $_ 
    }   
}
}