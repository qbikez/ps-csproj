
#todo: move this to logging module
function write-indented 
{
    param(
        [Parameter(ValueFromPipeline=$true, Position=1)]$msg, 
        [Parameter(Position=2)]$level, 
        [Parameter(Position=3)]$mark = "> ", 
        [Parameter(Position=4)]$maxlen, 
        [switch][bool]$passthru
    )
    begin {
        $pad = $mark.PadLeft($level)
        if ($maxlen -eq $null) {
            if ($host.UI.RawUI.WindowSize.Width -gt 0) {
                $maxlen = $host.UI.RawUI.WindowSize.Width - $level - 1
            }
            else {
                $maxlen = 512
            }
        }
    }
    process { 
        $msgs = @($msg)
        $msgs | % {        
            @($_.ToString().split("`n")) | % {
                $msg = $_
                $idx = 0    
                while($idx -lt $msg.length) {
                    $chunk = [System.Math]::Min($msg.length - $idx, $maxlen)
                    $chunk = [System.Math]::Max($chunk, 0)
                    write-host "$pad$($msg.substring($idx,$chunk))" #[$($msg.GetType().Name)]
                    $idx += $chunk
                    if ($passthru) {
                        write-output $msgs
                    }
                }
            }
        }
    }
}

function invoke {
[CmdletBinding(DefaultParameterSetName="set1")]
param(
    [parameter(Mandatory=$true,ParameterSetName="set1", Position=1)]
    [parameter(Mandatory=$true,ParameterSetName="in",Position=1)]
    $command,      
    [parameter(ValueFromRemainingArguments=$true,ParameterSetName="set1",Position=2)]
    [Parameter(ValueFromRemainingArguments=$true,ParameterSetName="in",Position=2)]
    $arguments, 
    [switch][bool]$nothrow, 
    [switch][bool]$showoutput = $true,
    [switch][bool]$silent,
    [switch][bool]$passthru,
    [Parameter(ParameterSetName="in")]
    $in
    ) 
    if ($silent) { $showoutput = $false }
    if ($arguments -ne $null) { 
        
        $argstr = ""
        for($i = 0; $i -lt @($arguments).count; $i++) {
            $argstr += "[$i] $($arguments[$i])`r`n"
        } 
        write-verbose "Invoking: '$command' in '$($pwd.path)' arguments ($(@($arguments).count)):`r`n$argstr"
    }
    else {
        write-verbose "Invoking: '$command' with no args in '$($pwd.path)'"
    }
    
    if ($showoutput) {
        write-host "  ===== $command ====="
        if ($in -ne $null) {
            $o = $in | & $command $arguments 2>&1 | write-indented -level 2 -passthru:$passthru
        } else {
            $o = & $command $arguments 2>&1 | write-indented -level 2 -passthru:$passthru
        }
        
        write-host "  === END $command == ($lastexitcode)" 
    } else {
        if ($in -ne $null) {
            $o = $in | & $command $arguments 2>&1
        }
        else {
            $o = & $command $arguments 2>&1
        }
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


function Test-IsAdmin() {
    return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
}

function Invoke-AsAdmin($ArgumentList, $proc = "powershell", [switch][bool] $Wait = $trie) {	
	if (!(test-IsAdmin)) {
		Start-Process $proc -Verb runAs -ArgumentList $ArgumentList -wait:$Wait
    } else {
		& $proc $argumentlist | out-default
    }
}

New-alias Run-AsAdmin Invoke-AsAdmin
New-alias sudo Invoke-AsAdmin

Export-ModuleMember -Function * -Alias *