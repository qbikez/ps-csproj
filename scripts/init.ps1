& "$PSScriptRoot\lib\init.ps1"

if (!(get-command nuget -ErrorAction ignore)) {
    choco install -y nuget.commandline
}

$dotnetsdk = $null
if ((get-command dotnet -ErrorAction ignore)) {
    $sdks = dotnet --list-sdks
    $matching = $sdks | ? { $_.Trim().StartsWith("3.1.") }
    if ($matching) {
        $dotnetsdk = @($matching) | select -first 1
    }
}
if (!$dotnetsdk) {
    write-host "dotnet sdk version 3.1.* not found. Installing..."
    choco install dotnetcore-sdk -y --sxs --version 3.1.300
}

& "$PSScriptRoot\build"
