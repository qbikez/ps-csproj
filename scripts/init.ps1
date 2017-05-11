& "$PSScriptRoot\lib\init.ps1"


# sdk 1.1.1 is required for powerecho compilation
choco install dotnetcore-sdk -y --sxs --version 1.0.0-RC2
choco install dotnetcore-sdk -y --sxs --version 1.1.1