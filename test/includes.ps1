$root = $psscriptroot
if ([string]::isnullorempty($root)) {
    $root = "."
}
. "$root\..\src\csproj\csproj-utils.ps1"
. "$root\..\src\csproj\sln-utils.ps1"

import-module pester

if ((get-module -listavailable logging) -ne $null) {
    import-module logging -DisableNameChecking

    $Global:logpattern.Add("""(?<magenta>.*?)""", "quoted names")
    $Global:logpattern.Add("<(?<cyan>[a-zA-Z]+)", "xml node start")
    $Global:logpattern.Add("/(?<cyan>[a-zA-Z]+)>", "xml node end")
}
else {
    function log-info($message = "") {
        write-host -ForegroundColor Cyan $message
    }
}

$inputdir = "$psscriptroot\input"