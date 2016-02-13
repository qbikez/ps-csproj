$root = $psscriptroot
if ([string]::isnullorempty($root)) {
    $root = "."
}

import-module pester

$env:PSModulePath ="$root\..\src;$env:PSModulePath"
if (gmo csproj) { rmo csproj }
import-module "csproj"


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