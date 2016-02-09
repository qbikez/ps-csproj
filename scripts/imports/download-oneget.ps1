function download-oneget() {
    $url = "https://download.microsoft.com/download/4/1/A/41A369FA-AA36-4EE9-845B-20BCC1691FC5/PackageManagement_x64.msi"

    $tmpdir = "temp"
    if (!(test-path $tmpdir)) {
        $null = new-item -type Directory $tmpdir
    }

    $dest = "$tmpdir\PackageManagement_x64.msi"
    $log = "$tmpdir\log.txt"
    if (!(test-path $dest)) {
        write-host "downloading $dest"
        wget -Uri $url -OutFile $dest
    }
    write-host "installing $dest"
    $out = & cmd /c start /wait msiexec /i $dest /qn /passive /log "$log"
    write-host "install done"
    write-host "## log: ##"
    Get-Content $log | write-host
    write-host "## log end ##"
    fix-oneget
}

function fix-oneget() {
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        $target = (get-module powershellget -ListAvailable).path        
        $target = join-path (split-path -parent $target) "PSGet.psm1"
        $src = "https://raw.githubusercontent.com/qbikez/PowerShellGet/master/PowerShellGet/PSGet.psm1"
        $tmp = "$tmpdir\PSGet.psm1"
        write-host "downloading patched Psget.psm1 from $src to $tmp"
        wget $src -OutFile $tmp
        write-host "overwriting $target with $tmp"
        Copy-Item $tmp $target -Force -Verbose
    }
}
