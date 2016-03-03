function Get-AssemblyMetaKey($key) {
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
    $key = get-assemblymetakey $key
    $assemblyinfo = get-assemblymetafile $assemblyinfo
    $content = get-content $assemblyinfo   
    $key = [System.Globalization.CultureInfo]::CurrentCulture.TextInfo.ToTitleCase($key)
    $content | % {
        $regex = "\[assembly: ($($key))\(""(?<value>.*)""\)\]"
        if ($_ -match $regex -and !($_.trim().startswith("//"))) {
            $matches["value"]            
        }          
    }
}

function set-AssemblyMeta {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ($key, $value, $assemblyinfo = ".") 
    $key = get-assemblymetakey $key
    $assemblyinfo = get-assemblymetafile $assemblyinfo
    # [assembly: AssemblyCompany("")]
    $content = get-content $assemblyinfo   
    $key = [System.Globalization.CultureInfo]::CurrentCulture.TextInfo.ToTitleCase($key)
    $content = $content | % {
        $regex = "\[assembly: ($($key))\(""(.*)""\)\]"
        $newval = $_
        if ($_ -match $regex) {            
            $newval = $newval  -replace $regex,"[assembly: `${1}(""$($value)"")]"
            write-verbose "replacing: $_ => $newval"
        } 
        $newval
    } 
    if ($PSCmdlet.ShouldProcess("save output file '$assemblyinfo'")) {
        $content | out-file $assemblyinfo -Encoding utf8
    }
}