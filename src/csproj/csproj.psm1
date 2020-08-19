$root = "."
if (![string]::IsNullOrEmpty($PSScriptRoot)) {
    $root = $PSScriptRoot
}
#if ($MyInvocation.MyCommand.Definition -ne $null) {
#    $root = $MyInvocation.MyCommand.Definition
#}
$helpersPath = $root

# grab functions from files
get-childitem "$helpersPath\functions" -filter "*.ps1" | 
    ? { -not ($_.Name.Contains(".Tests.")) } |
    % { . $_.FullName }

get-childitem "$helpersPath\scan" -filter "*.ps1" | 
    ? { -not ($_.Name.Contains(".Tests.")) } |
    % { . $_.FullName }

get-childitem "$helpersPath\commandline" -filter "*.ps1" | 
    ? { -not ($_.Name.Contains(".Tests.")) } |
    % { . $_.FullName }

#Export-ModuleMember -Function *
Export-ModuleMember -function `
    Import-Sln, Get-Slnprojects, Remove-SlnProject, Update-SlnProject, `
    find-RepoRoot, Find-GlobalJson, Get-InstalledNugets, Get-AvailableNugets, `
    Get-PackageVersion, Get-PackageName, `
    import-csproj, get-nodes, get-projectreferences, get-externalreferences, get-nugetreferences, get-systemreferences,  get-allreferences, add-projectItem, convertto-nuget, convert-reference, `
    get-packagesconfig, set-packagesconfig, add-packagetoconfig, remove-packagefromconfig, `
    convert-referencestonuget, get-referencesTo, convertto-projectreference, convertto-nugetreference, convert-nugetToProjectReference, `
    set-assemblymeta, get-assemblymeta, `
    get-slndependencies, test-sln, test-slndependencies, repair-slnpaths, get-csprojdependencies, repair-csprojpaths, `
    convert-packagestoprojectjson, repair-ProjectJSonProjectReferences, `
    initialize-projects, push-nugets, use-projects, `
    Copy-BindingRedirects, `
    update-referencesToStable, find-unstablePackages, `
	get-csprojdeps `
    -Alias *
