try {
    cd "$psscriptroot\..\test\tools\powerecho"
    dotnet publish -r win10-x64
} finally {
    popd
}