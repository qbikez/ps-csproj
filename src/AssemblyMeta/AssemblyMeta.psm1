function Get-AssemblyMetaKey {
[CmdletBinding()]
param($key, $type = "cs")
    if ($type -eq "json") {
        $r = switch($key)  {
            { @("InformationalVersion","AssemblyInformationalVersion") -eq $_ } { "version"; break; }
            "Description" { "description"; break; }
            default { $null; break; }
        }
        return $r
    }
    else {
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
}

function Get-AssemblyMetaFile {
[CmdletBinding()]
param($path = ".")

    if ($path.EndsWith(".cs") -or $path.EndsWith("project.json")) {
        return $path
    }
    if (test-path $path) {
        $i = get-item $path
        if (!($i.psiscontainer)) {
            $path = split-path -parent $path
            $i = get-item $path
        }
        if ($i.psiscontainer) {
            $files = @()
            if (test-path "$path/project.json") { $files += @("$path/project.json")}
            if (test-path "$path/AssemblyVersionInfo.cs") { $files += @("$path/AssemblyVersionInfo.cs") }
            if (test-path "$path/Properties/AssemblyInfo.cs") { $files += @("$path/Properties/AssemblyInfo.cs") }
            if (test-path "$path/AssemblyInfo.cs") { $files += @("$path/AssemblyInfo.cs") }            
            if ($files.length -gt 0) { return $files }
        }
        
        throw "AssemblyInfo not found in '$($i.fullname)'"    
    }
    else {
        throw "Path not found: '$path'"
    }
    
    
}

function Get-AssemblyMeta {
    [CmdletBinding()]
    param ($key, $assemblyinfo = ".", [switch][bool] $table)

    $originalKey = $key
    $assemblyinfos = get-assemblymetafile $assemblyinfo
    if ($key -eq $null) { $table = $true }
    
    $value = $null
    
    foreach($assemblyinfo in $assemblyinfos) {
        write-verbose "cheking file '$assemblyinfo' for assembly info"
        if ($assemblyinfo.endswith("project.json")) 
        {            
            $key = get-assemblymetakey $originalKey -type "json"
            if ($key -eq $null) {
                continue
            }
            try {
                import-module newtonsoft.json
                $json = get-content $assemblyinfo | out-string | convertfrom-jsonnewtonsoft
            } catch {
                write-error "failed to parse json from file '$assemblyinfo'"
                throw $_
            } 
            if ($json.$key -ne $null) {
                if ($table) {
                    return new-object -type pscustomobject -property @{
                        key = $key; value = $json.$key; file = $assemblyinfo
                    }
                }
                else {
                    return $json.$key
                }            
            }
        }
        else {
            $key = get-assemblymetakey $originalKey     
            write-verbose "looking for key '$key' in '$assemblyinfo'"
            $content = get-content $assemblyinfo   
            $value = $content | % {
                $regex = "\[assembly: (System\.Reflection\.){0,1}(?<key>$($key))\(""(?<value>.*)""\)\]"
                if ($_ -match $regex -and !($_.trim().startswith("//"))) {
                    if ($table) {
                        return new-object -type pscustomobject -property @{
                            key = $matches["key"]; value = $matches["value"]; file = $assemblyinfo
                        }
                    }
                    else {
                        return $matches["value"]
                    }            
                }          
            }           
        }
        if ($value -ne $null) {
            break
        }
    }
    
    return $value
}

function Set-AssemblyMeta {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ($key, $value, $assemblyinfo = ".") 
    $originalKey = $key
    
    $originalFile = 
    $assemblyinfos = @(get-assemblymetafile $assemblyinfo)
    
    foreach($assemblyinfo in $assemblyinfos) {
        if ($assemblyinfo.endswith("project.json"))
        {
            $key = get-assemblymetakey $originalKey -type "json"
            if ($key -eq $null) {
                write-host "don't know a matching project.json key for '$originalKey'"
                continue
            }
            import-module newtonsoft.json
            $json = get-content $assemblyinfo | out-string | convertfrom-jsonnewtonsoft 
            $json.$key = $value

            ipmo publishmap
            #$json = convertto-hashtable $json -recurse
            $json | convertto-jsonnewtonsoft | out-file $assemblyinfo -encoding utf8    
        }
        else {
            $key = get-assemblymetakey $originalKey
            # [assembly: AssemblyCompany("")]
            $content = get-content $assemblyinfo   
            
            $found = $false
            $content = $content | % {
                $newval = $_
                $regex = "\[assembly: ($($key))\(""(.*)""\)\]"
                if ($_ -notmatch $regex) {
                    $regex = "\[assembly: (System\.Reflection\.$($key))\(""(.*)""\)\]"
                }
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
    }
}

function Update-AssemblyVersion {
[CmdletBinding()]
param($version, $path = ".") 

    $ver = $version
    
    $v = get-assemblymeta "Version" $path
    if ([string]::isnullorempty($v) -or $v -eq "1.0.0.0" -or $version -ne $null) {
        set-assemblymeta "Version" ((split-packageversion $ver)["version"]) $path
    }
    $v = get-assemblymeta "FileVersion" $path
    if ([string]::isnullorempty($v) -or $v -eq "1.0.0.0" -or $version -ne $null) {
        set-assemblymeta "FileVersion" ((split-packageversion $ver)["version"]) $path
    }
    
    $v = get-assemblymeta "InformationalVersion" $path
    if ([string]::isnullorempty($v) -or $v -eq "1.0.0.0"  -or $version -ne $null) {
        set-assemblymeta "InformationalVersion" $ver $path
    }
}


function split-packageVersion($version) {
    $m = $version -match "(?<version>[0-9]+(\.[0-9]+)*)+(?<suffix>-.*){0,1}$"
    return $matches
}