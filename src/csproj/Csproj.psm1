$root = "."
if (![string]::IsNullOrEmpty($PSScriptRoot)) {
    $root = $PSScriptRoot
}
#if ($MyInvocation.MyCommand.Definition -ne $null) {
#    $root = $MyInvocation.MyCommand.Definition
#}
$helpersPath = $root

# grab functions from files
Resolve-Path $helpersPath\functions\*.ps1 | 
    ? { -not ($_.ProviderPath.Contains(".Tests.")) } |
    % { . $_.ProviderPath }



#Export-ModuleMember -Function *
Export-ModuleMember -function `
    import-sln, get-slnprojects, remove-slnproject, `
    find-nugetpath, `
    import-csproj, get-nodes, get-projectreferences, get-externalreferences, get-nugetreferences, get-systemreferences,  get-allreferences, add-projectItem, convertto-nuget, replace-reference