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