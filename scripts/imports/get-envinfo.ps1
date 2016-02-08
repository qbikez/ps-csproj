function get-envinfo($checkcommands) {
    $result = @{} 
    
    write-host "Powershell version:"    
    $result.Version = $PSVersionTable.PSVersion 
    $result.Version | format-table | out-string | write-host
    
    write-host "Available commands:"
    if ($checkcommands -eq $null) {
        $commands = "Install-Module"
    } else {
        $commands = $checkcommands
    }
    $result.Commands = @{}    
    $commands | % {
        $c = $_
        try {
            $cmd = get-command $c -ErrorAction SilentlyContinue
            $result.Commands[$_] = $cmd
        } catch {
            $cmd = $null
        }
        if ($cmd -eq $null) {
            write-warning "$($c):`t MISSING"            
        }
        else {
             write-host "$($c):`t $(($cmd | format-table -HideTableHeaders | out-string) -replace ""`r`n"",'')"
        }
    }

    return $result
    
}
