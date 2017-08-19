function get-frameworkssorted([Parameter(ValueFromPipeline=$true)] $frameworks, $frameworkhint) {
begin {
    $ordered = @()
}
process {
    $order = switch($_.name) {
        $frameworkhint { 0; break }
        {$_ -match "^net" } { 10; break }
        {$_ -match "^dnx" }  { 20; break }
        default { 100; break }
    }
    $ordered += @( New-Object -type pscustomobject -Property @{
            dir = $_
            order = $order
        })
}
end {
    $ordered = $ordered | sort dir -Descending | sort order 
    return $ordered | select -ExpandProperty dir
    }
}


New-Alias sort-frameworks get-frameworkssorted -Force