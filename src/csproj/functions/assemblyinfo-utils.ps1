function Get-AssemblyMetaKey($key) {
    if ($key -eq $null) {
        return "Assembly.*"
    }
    $key = "$("$($key[0])".ToUpper()[0])" + $key.Substring(1)
    
    if ($key.StartsWith("Assembly")) {
        return $key
    }
    else {
        return "Assembly$key"
    }
}

function Get-AssemblyMetaFile($path = ".") {
    if ($path.EndsWith(".cs")) {
        return $path
    }
    if (test-path $path) {
        $i = get-item $path
        if (!($i.psiscontainer)) {
            $path = split-path -parent $path
            $i = get-item $path
        }
        if ($i.psiscontainer) {
            if (test-path "$path/Properties/AssemblyInfo.cs") { return "$path/Properties/AssemblyInfo.cs" }
            if (test-path "$path/AssemblyInfo.cs") { return "$path/AssemblyInfo.cs" }
        }
        
        throw "AssemblyInfo not found in '$($i.fullname)'"    
    }
    else {
        throw "Path not found: '$path'"
    }
    
    
}

function Get-AssemblyMeta {
    [CmdletBinding()]
    param ($key, $assemblyinfo = ".")
    if ($key -eq $null) { $table = $true }
    $key = get-assemblymetakey $key
    $assemblyinfo = get-assemblymetafile $assemblyinfo
    $content = get-content $assemblyinfo   
    $r = $content | % {
        $regex = "\[assembly: (?<key>$($key))\(""(?<value>.*)""\)\]"
        if ($_ -match $regex -and !($_.trim().startswith("//"))) {
            if ($table) {
                return new-object -type pscustomobject -property @{
                    key = $matches["key"]; value = $matches["value"]
                }
            }
            else {
                return $matches["value"]
            }            
        }          
    }
    
    return $r
}

function set-AssemblyMeta {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ($key, $value, $assemblyinfo = ".") 
    $key = get-assemblymetakey $key
    $assemblyinfo = get-assemblymetafile $assemblyinfo
    # [assembly: AssemblyCompany("")]
    $content = get-content $assemblyinfo   
    
    $found = $false
    $content = $content | % {
        $regex = "\[assembly: ($($key))\(""(.*)""\)\]"
        $newval = $_
        if ($_ -match $regex) {            
            $newval = $newval -replace $regex,"[assembly: `${1}(""$($value)"")]"
            $found = $true
            write-verbose "replacing: $_ => $newval"
        } 
        $newval
    } 
    if (!$found) {
        $content += "[assembly: $key(""$($value)"")]"
    }
    if ($PSCmdlet.ShouldProcess("save output file '$assemblyinfo'")) {
        $content | out-file $assemblyinfo -Encoding utf8
    }
}