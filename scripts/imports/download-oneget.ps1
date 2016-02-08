function download-oneget() {
$url = "https://download.microsoft.com/download/4/1/A/41A369FA-AA36-4EE9-845B-20BCC1691FC5/PackageManagement_x64.msi"

$dest = "$($env:USERPROFILE)\PackageManagement_x64.msi"
$log = "$($env:USERPROFILE)\log.txt"
if (!(test-path $dest)) {
    write-host "downloading $dest"
    wget -Uri $url -OutFile $dest
}
    write-host "installing $dest"
    & cmd /c start /wait msiexec /i $dest /qn /passive /log "$log"
    write-host "install done"
    write-host "log:"
    Get-Content $log | write-host
    write-host "log end"
}

download-oneget