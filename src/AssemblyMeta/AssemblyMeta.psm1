function Get-AssemblyMetaKey {
[CmdletBinding()]
param(
    $key, 
    [ValidateSet("cs","json","csproj")]
    $type = "cs"
)
    switch($type) {
        "json" {
            if ($key -eq $null) {
                return 
            }
            $r = switch($key)  {
                { $_ -in @("InformationalVersion","AssemblyInformationalVersion") } { "version"; break; }
                "Description" { "description"; break; }
                default { $null; break; }
            }
            return $r
        }
        "cs" {
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
        "csproj" {
            $r = switch($key)  {
                { $_ -in @("InformationalVersion","AssemblyInformationalVersion") } { "VersionPrefix-VersionSuffix","Version"; break; }
                { $_ -in @("Version","AssemblyVersion")  } { "VersionPrefix","Version"; break; }
                { $_ -in @("FileVersion")} { $null; break; }
                default { $key; break; }
            }
            return $r
        }
    }
   
}

function Get-AssemblyMetaFile {
[CmdletBinding()]
param($path = ".")

    if ($path.EndsWith(".cs") -or $path.EndsWith("project.json") -or $path.EndsWith(".csproj")) {
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
            if (test-path "$path/GeneratedAssemblyInfo.cs") { $files += @("$path/GeneratedAssemblyInfo.cs") }                        
            $dir = split-path -leaf $path            
            if ((test-path $path/$dir.csproj)) { $files +=@("$path/$dir.csproj")  }
            else {
                $files += get-childitem $path -File -Filter "*.csproj"
            }
            if ($files.length -gt 0) { return $files }
        }
        if ($ErrorActionPreference -ne "Ignore") {
            throw "AssemblyInfo not found in '$($i.fullname)'"
        } else {
            return $null
        }
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
    
    $value = @()
    foreach($assemblyinfo in $assemblyinfos) {
        write-verbose "cheking file '$assemblyinfo' for assembly info"
        if ($assemblyinfo.endswith("project.json")) 
        {            
            $key = get-assemblymetakey $originalKey -type "json"
            write-verbose "looking for key '$key' in '$assemblyinfo'"
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
            foreach($k in @($key)) {
                if ($json.$k -ne $null) {
                    if ($table) {
                        $value += @(new-object -type pscustomobject -property @{
                            key = $k; value = $json.$k; file = $assemblyinfo; fileKey = $k
                        })
                        continue
                    }
                    else {
                        return $json.$k
                    }            
                }
            }
        }
        elseif ($assemblyinfo.endswith(".csproj"))
        {            
            $key = get-assemblymetakey $originalKey -type "csproj"
            write-verbose "looking for key '$key' in '$assemblyinfo'"
            if ($key -eq $null) {
                continue
            }            
            if (!(test-path $assemblyinfo)) { throw "assembly meta file '$assemblyinfo' not found" }
            try {
                $xml = [xml](get-content $assemblyinfo)                
            } catch {
                write-error "failed to parse xml  from file '$assemblyinfo'"
                throw $_
            } 
            foreach($k in @($key)) {  
                $separator = "-"              
                $splits = $k.Split($separator)
                $values = @()
                foreach($s in $splits) {
                    foreach($g in $xml.Project.PropertyGroup) {
                        if ($g[$s] -ne $null) {
                            $values += $g[$s].InnerText
                            break
                        }
                    }
                }
                if ($values.count -eq $splits.count) {
                    $val = [string]::Join($separator, $values)
                    if ($table) {
                        $value += @(new-object -type pscustomobject -property @{
                            key = $k; value = $val; file = $assemblyinfo; fileKey = $k
                        })
                        continue
                    }
                    else {
                        return $val
                    }                         
                }
            }
        }
        else {
            $key = get-assemblymetakey $originalKey     
            write-verbose "looking for key '$key' in '$assemblyinfo'"
            $content = get-content $assemblyinfo   
            $value += @($content | % {
                $regex = "\[assembly: (?<fileKey>(System\.Reflection\.){0,1}(?<key>$($key))(Attribute){0,1})\(""(?<value>.*)""\)\]"
                if ($_ -match $regex -and !($_.trim().startswith("//"))) {
                    if ($table) {
                        return new-object -type pscustomobject -property @{
                            key = $matches["key"]; value = $matches["value"]; file = $assemblyinfo; fileKey=$matches["fileKey"]
                        }
                    }
                    else {
                        return $matches["value"]
                    }            
                }          
            })           
        }       
    }
    
    return $value
}

function Set-AssemblyMeta {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ($key, $value, $assemblyinfo = ".") 
    $originalKey = $key
    
    $current = get-assemblymeta $key $assemblyinfo -table
    $assemblyinfos = @(get-assemblymetafile $assemblyinfo)
    if ($current -ne $null) {
        $json = $assemblyinfos | ? {$_.endswith("project.json") }
        $assemblyinfos = @($current.File) + @($json)
    }
    $jsonSet = $false
    $csSet = $false
    foreach($assemblyinfo in $assemblyinfos) {
        if ($assemblyinfo.endswith("project.json"))
        {
            #only set value in one of json files
            if ($current -eq $null -and $jsonSet) { continue }

            $key = get-assemblymetakey $originalKey -type "json"
            if ($key -eq $null) {
                write-host "don't know a matching project.json key for '$originalKey'"
                continue
            }
            import-module newtonsoft.json
            $json = get-content $assemblyinfo | out-string | convertfrom-jsonnewtonsoft 
            $json.$key = $value           
            $jsonSet = $true
            write-verbose "setting json value '$key' to '$value' in $assemblyinfo"
            #ipmo publishmap
            #$json = convertto-hashtable $json -recurse
            $json | convertto-jsonnewtonsoft | out-file $assemblyinfo -encoding utf8  
        }
        elseif ($assemblyinfo.endswith(".csproj")) {   
            $key = get-assemblymetakey $originalKey -type "csproj"
            write-verbose "looking for key '$key' in '$assemblyinfo'"
            if ($key -eq $null) {
                continue
            }            
            if (!(test-path $assemblyinfo)) { throw "assembly meta file '$assemblyinfo' not found" }
            try {
                $xml = [xml](get-content $assemblyinfo)                
            } catch {
                write-error "failed to parse xml  from file '$assemblyinfo'"
                throw $_
            } 
            $k = @($key) | select -first 1

            function set-xmlproperty($xml, $key, $value) {
                $node = $null
                $s = $key
                foreach($g in $xml.Project.PropertyGroup) {
                    if ($g[$s] -ne $null) {
                        
                        $node = $g[$s]
                        break
                    }
                }
                if ($node -eq $null) {
                    throw "missing node '$key'. adding xml nodes is not implemented yet"
                }
                write-verbose "setting xml property '$s'='$value'" -verbose
                $node.InnerText = $value
            }

            $separator = "-"              
            if ($k.Contains($separator)) {
                $idx = $value.IndexOf($separator)
                $values = @($value.substring(0, $idx), $value.substring($idx+1))
                $keys = $k.split($separator)
                for ($i = 0; $i -lt $values.length; $i++) {
                    set-xmlproperty $xml $keys[$i] $values[$i]
                }
            } else {
                set-xmlproperty $xml $k $value
            }

            $xml.Save((get-item $assemblyinfo).FullName)                        
        }
        elseif ($assemblyinfo.endswith(".cs")) {            #only set value in one of cs files
            if ($current -eq $null -and $csSet) { continue }
            $key = get-assemblymetakey $originalKey

            if ($current -ne $null) {
                $ck = $current | ? { $_.file -eq $assemblyinfo }
                if ($ck -ne $null) { $key = $ck.filekey }
            }
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
                    $csSet = $true
                } 
                $newval
            } 
            if (!$found -and $current -eq $null) {
                $content += "[assembly: System.Reflection.$key(""$($value)"")]"
                $csSet = $true
            }
            if ($PSCmdlet.ShouldProcess("save output file '$assemblyinfo'")) {
                $content | out-file $assemblyinfo -Encoding utf8
            }
        }
        else {
            throw "don't know how to update $assemblyinfo"
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