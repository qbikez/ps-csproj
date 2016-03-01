function set-assemblymeta {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ($key, $value, $assemblyinfo = "Properties/AssemblyInfo.cs") 
    # [assembly: AssemblyCompany("")]
    $content = get-content $assemblyinfo   
    $key = [System.Globalization.CultureInfo]::CurrentCulture.TextInfo.ToTitleCase($key)
    $content = $content | % {
        $regex = "\[assembly: (Assembly$($key))\(""(.*)""\)\]"
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