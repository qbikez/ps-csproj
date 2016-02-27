$root = $psscriptroot
if ([string]::isnullorempty($root)) {
    $root = "."
}

#if ($host.name -eq "Windows PowerShell ISE Host" -and (gmo pester)) { rmo pester }
import-module pester
$i = (gi "$root\..\src")
$fp = (gi "$root\..\src").fullname
write-verbose "adding path of $i '$fp' to psmodulepath"
$env:PSModulePath ="$fp;$env:PSModulePath"

if ($host.name -eq "Windows PowerShell ISE Host") {
    if (gmo csproj) { rmo csproj }
    import-module csproj -DisableNameChecking
}


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

function get-outdir() {
    #$targetdir = "testdrive:"
   
    $targetdir = "$psscriptroot\test-results\$(get-date -Format "yyyy-MM-dd HHmmss")"
    if (!(test-path $targetdir)) { $null = new-item -ItemType directory $targetdir }
    return $targetdir
}