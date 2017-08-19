& "$PSScriptRoot\lib\restore.ps1"

install-module pathutils -verbose
install-module publishmap -verbose
install-module crayon -verbose
install-module newtonsoft.json -verbose

pushd 
try {
    cd "$psscriptroot\..\test\tools\powerecho"
    dotnet restore 
} finally {
    popd
}