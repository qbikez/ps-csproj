function download-oneget() {
$url = "https://download.microsoft.com/download/4/1/A/41A369FA-AA36-4EE9-845B-20BCC1691FC5/PackageManagement_x64.msi"

$dest = ".\PackageManagement_x64.msi"
#if (!(test-path $dest)) {
    wget -Uri $url -OutFile $dest
#}

& $dest /quiet
}