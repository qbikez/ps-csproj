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
    Import-Sln, Get-Slnprojects, Remove-SlnProject, Update-SlnProject, `
    Find-Nugetpath, Get-NugetToolsPath, Get-InstalledNugets, Get-AvailableNugets, `
    Invoke-NugetPack, Invoke-NugetPush, Get-PackageVersion, Get-PackageName, Update-NugetMeta, update-buildversion, `
    import-csproj, get-nodes, get-projectreferences, get-externalreferences, get-nugetreferences, get-systemreferences,  get-allreferences, add-projectItem, convertto-nuget, convert-reference, `
    get-packagesconfig, add-packagetoconfig, remove-packagefromconfig, `
    convert-referencestonuget, get-referencesTo, convertto-projectreference, convertto-nugetreference, convert-nugetToProjectReference, `
    set-assemblymeta, get-assemblymeta, `
    get-slndependencies, test-slndependencies, repair-slnpaths, get-csprojdependencies, repair-csprojpaths, write-indented `
    -Alias *
