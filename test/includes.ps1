$root = $psscriptroot
if ([string]::isnullorempty($root)) {
    $root = "."
}
. "$root\..\src\csproj\csproj-utils.ps1"