& "$PSScriptRoot\lib\init.ps1"

if (!(get-command nuget -ErrorAction Ignore)) {
    choco install -y nuget.commandline
}

# sdk 1.1.1 is required for powerecho compilation
choco install dotnetcore-sdk -y --sxs --version 1.0.0-RC2 # this corresponds to sdk version 1.0.0-preview1-002702 needed by test input
choco install dotnetcore-sdk -y --sxs --version 1.1.11 # needed by powerecho tool

