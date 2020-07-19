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

# no idea why it's not exported in Pester 5.0.2
function In {
    <#
    .SYNOPSIS
    A convenience function that executes a script from a specified path.

    .DESCRIPTION
    Before the script block passed to the execute parameter is invoked,
    the current location is set to the path specified. Once the script
    block has been executed, the location will be reset to the location
    the script was in prior to calling In.

    .PARAMETER Path
    The path that the execute block will be executed in.

    .PARAMETER execute
    The script to be executed in the path provided.

    .LINK
    https://github.com/pester/Pester/wiki/In

    #>
    [CmdletBinding(DefaultParameterSetName="Default")]
    param(
        [Parameter(Mandatory, ParameterSetName="Default", Position=0)]
        [String] $Path,
        [Parameter(Mandatory, ParameterSetName="TestDrive", Position=0)]
        [Switch] $TestDrive,
        [Parameter(Mandatory, Position = 1)]
        [Alias("Execute")]
        [ScriptBlock] $ScriptBlock
    )

    # test drive is not available during discovery, ideally no code should
    # depend on location during discovery, but I cannot rely on that, so unless
    # the path is TestDrive the path is changed in discovery as well as during
    # the run phase
    $doNothing = $false
    if ($TestDrive) {
        if (Is-Discovery) {
            $doNothing = $true
        }
        else {
            $Path = (Get-PSDrive 'TestDrive').Root
        }
    }

    $originalPath = $pwd
    if (-not $doNothing) {
        & Set-Location $Path
        $pwd = $Path
    }
    try {
        & $ScriptBlock
    }
    finally {
        if (-not $doNothing) {
            & Set-Location $originalPath
            $pwd = $originalPath
        }
    }
}

write-host "== includes END =="