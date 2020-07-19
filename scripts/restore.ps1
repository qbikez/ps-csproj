& "$PSScriptRoot\lib\restore.ps1"

install-module pathutils -verbose
install-module publishmap -verbose
install-module crayon -verbose
install-module newtonsoft.json -verbose

import-module pathutils

where-is "dotnet"
dotnet --info

pushd
try {
    cd "$psscriptroot\..\test\tools\powerecho"
    dotnet --info
} finally {
    popd
}



pushd 
try {
    cd "$psscriptroot\..\test\tools\powerecho"
    dotnet restore 
} finally {
    popd
}

Install-Module pester -Scope CurrentUser -Force