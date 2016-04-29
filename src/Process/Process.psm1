
#todo: move this to logging module
function write-indented ([Parameter(ValueFromPipeline=$true, Position=1)]$msg, [Parameter(Position=2)]$level, [Parameter(Position=3)]$mark = "> ", [Parameter(Position=4)]$maxlen) {
    $pad = $mark.PadLeft($level)
    if ($maxlen -eq $null) {
        if ($host.UI.RawUI.WindowSize.Width -gt 0) {
            $maxlen = $host.UI.RawUI.WindowSize.Width - $level - 1
        }
        else {
            $maxlen = 512
        }
    }
    
    $msgs = @($msg)
    $msgs | % {        
        @($_.ToString().split("`n")) | % {
            $msg = $_
            $idx = 0    
            while($idx -lt $msg.length) {
                $chunk = [System.Math]::Min($msg.length - $idx, $maxlen)
                $chunk = [System.Math]::Max($chunk, 0)
                write-host "$pad$($msg.substring($idx,$chunk))"
                $idx += $chunk
            }
        }
    }
}


function invoke(
    [parameter(Mandatory=$true)]$command,  
    [parameter(ValueFromRemainingArguments=$true)][string[]]$arguments, 
    [switch][bool]$nothrow, 
    [switch][bool]$showoutput,
    $in) {
    if ($showoutput) {
        $o = $in | & $command $arguments 2>&1| write-indented -level 2
    } else {
        $o = $in | & $command $arguments 2>&1
    }
    if ($lastexitcode -ne 0) {
        if (!$nothrow) {
            $o | out-string | write-error 
        } else {
           $o | out-string | write-host 
        }
    }
    if (!$nothrow -and $lastexitcode -ne 0) {
        throw "Command returned $lastexitcode"
    }
    return $o
}