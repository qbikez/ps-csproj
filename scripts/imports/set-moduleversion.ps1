function Set-ModuleVersion(
    [parameter(mandatory=$true)]
    $path,
    [parameter(mandatory=$true)]
    [string]$version
    ) 
{
    if ($path.EndsWith(".psd1")) {
        $psd = $path
    }
    elseif ($path.EndsWith(".psm1")) {
        $psd = $path -replace ".psm1",".psd1"
    }
    else {
        $modulename = split-path -leaf $path
        $psd = "$path\$modulename.psd1"
    }
    if (!(test-path $psd)) {
        throw "psd1 file '$psd' not found"
    }

    $c = Get-Content $psd | Out-String 
    if ($c -match "ModuleVersion\s=\s'(.+)'") {
        write-host "replacing version $($Matches[1]) with $version in $psd"
    }
    $c = $c -replace "ModuleVersion\s=\s'.+'","ModuleVersion = '$version'" 
    $c | Out-File $psd -encoding utf8
}

function Get-ModuleVersion(
    [parameter(mandatory=$true)]
    $path
    ) 
{
    if ($path.EndsWith(".psd1")) {
        $psd = $path
    }
    elseif ($path.EndsWith(".psm1")) {
        $psd = $path -replace ".psm1",".psd1"
    }
    else {
        $modulename = split-path -leaf $path
        $psd = "$path\$modulename.psd1"
    }
    if (!(test-path $psd)) {
        throw "psd1 file '$psd' not found"
    }
    $c = Get-Content $psd | Out-String 
    if ($c -match "ModuleVersion\s=\s'(.+)'") {
        return $($Matches[1])
    }
    
    return $null
}
