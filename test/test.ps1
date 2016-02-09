
$Global:logpattern.Add("""(?<magenta>.*?)""", "quoted names")
$Global:logpattern.Add("<(?<cyan>[a-zA-Z]+)", "xml node start")
$Global:logpattern.Add("/(?<cyan>[a-zA-Z]+)>", "xml node end")

Push-Location
try {

cd $PSScriptRoot

$dir = ".\test\Platform\src\NowaEra.Model.Sync"
$csproj = load-csproj "$dir\NowaEra.Model.Sync.csproj"
$refs = get-projectreferences $csproj

log-info 
log-info "Project references:"

$refs | % {
    log-info $_.Node.OuterXml
}

log-info 
log-info "External references:"
get-externalreferences $csproj | % { log-info $_.Node.OuterXml }

log-info 
log-info "Nuget references:"
get-nugetreferences $csproj | % { log-info $_.Node.OuterXml }


log-info 
log-info "System references:"
get-systemreferences $csproj | % { log-info $_.Node.OuterXml }

Push-Location
try {
    cd $dir
    $packages =  "..\..\..\packages"
    find-nugetPath "AutoFac" $packages
    find-nugetPath "nothing" $packages
    find-nugetPath "Antlr" $packages
   convertto-nuget $refs[0].Node -packagesRelPath $packages
} finally {
    Pop-Location
}

$csproj.Save("$((gi $dir).FullName)\out.csproj")
} finally {
    Pop-Location
}

