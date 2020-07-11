& "$PSScriptRoot\lib\init.ps1"

if (!(get-command nuget)) {
    choco install -y nuget.commandline
}

choco install dotnetcore-sdk -y --sxs --version 3.1.300

