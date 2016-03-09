
#todo: move this to logging module
function write-indented ($level, $msg, $mark = "> ", $maxlen) {
    $pad = $mark.PadLeft($level)
    if ($maxlen -eq $null) {
        if ($host.UI.RawUI.WindowSize.Width -gt 0) {
            $maxlen = $host.UI.RawUI.WindowSize.Width - $level - 1
        }
        else {
            $maxlen = 512
        }
    }
    $idx = 0
    
    while($idx -lt $msg.length) {
        $chunk = [System.Math]::Min($msg.length - $idx, $maxlen)
        $chunk = [System.Math]::Max($chunk, 0)
        write-host "$pad$($msg.substring($idx,$chunk))"
        $idx += $chunk
    }
}


function invoke($command, [string[]]$arguments, [switch][bool]$nothrow, [switch][bool]$showoutput) {
    if ($showoutput) {
        $o = & $command $arguments 2>&1 | write-indented 2
    } else {
        $o = & $command $arguments 2>&1
    }
    if ($lastexitcode -ne 0) {
        $o | out-string | write-host
    }
    if (!$nothrow -and $lastexitcode -ne 0) {
        throw "Command returned $lastexitcode"
    }
}