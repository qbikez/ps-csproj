. $psscriptroot\imports\get-envinfo.ps1

$e = get-envinfo -checkcommands "Install-Module"

if ($e.commands["Install-Module"] -eq $null) {
    . $psscriptroot\imports\download-oneget.ps1

    download-oneget
}