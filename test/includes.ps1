$root = $psscriptroot
if ([string]::isnullorempty($root)) {
    $root = "."
}

write-host "== includes 64bit=$([Environment]::Is64BitProcess) =="

import-module require
#if ($host.name -eq "Windows PowerShell ISE Host" -and (gmo pester)) { rmo pester }
req pester
req pathutils
$i = (gi "$root\..\src")
$fp = (gi "$root\..\src").fullname
write-verbose "adding path of $i '$fp' to psmodulepath"
pathutils\add-toenvvar "PsModulePath" "$fp" -first

if ((pwd).Drive.Name -eq "TestDrive") {
    cd c:\
}

req crayon

#if ((get-module chalk) -eq $null) {
#    write-host "importing chalk"
#    import-module chalk -DisableNameChecking    
#    if ((get-module chalk) -ne $null) {
        $Global:logpattern.Add("""(?<magenta>.*?)""", "quoted names")
        $Global:logpattern.Add("<(?<cyan>[a-zA-Z]+)", "xml node start")
        $Global:logpattern.Add("/(?<cyan>[a-zA-Z]+)>", "xml node end")
#    }
#    else {
#        function log-info($message = "") {
#            write-host -ForegroundColor Cyan $message
#        }
#    }
#}

$inputdir = "$psscriptroot\input"

function get-testoutputdir() {
    $targetdir = "TestDrive:"
    if (get-command get-pesterstate -ErrorAction Ignore -and $false) {
        $s = get-pesterstate
        $targetdir = "$psscriptroot\test-results\$(get-date -Format "yyyy-MM-dd HHmmss")-$($s.currentdescribe)"
    }
    if (!(test-path $targetdir)) { $null = new-item -ItemType directory $targetdir }
    return $targetdir
}

function copy-samples() {
    $targetdir = get-testoutputdir
    copy-item "$inputdir/test" "$targetdir" -Recurse
    copy-item "$inputdir/packages" "$targetdir/test" -Recurse -force
    copy-item "$inputdir/packages-repo" "$targetdir" -Recurse -force

    return $targetdir
}


write-host "== includes END =="