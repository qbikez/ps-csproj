$root = $psscriptroot
if ([string]::isnullorempty($root)) {
    $root = "."
}
. "$root\..\src\csproj\csproj-utils.ps1"

import-module pester


#import-module logging

#$Global:logpattern.Add("""(?<magenta>.*?)""", "quoted names")
#$Global:logpattern.Add("<(?<cyan>[a-zA-Z]+)", "xml node start")
#$Global:logpattern.Add("/(?<cyan>[a-zA-Z]+)>", "xml node end")

function log-info($message = "") {
    write-host -ForegroundColor Cyan $message
}