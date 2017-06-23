$root = "."
if (![string]::IsNullOrEmpty($PSScriptRoot)) {
    $root = $PSScriptRoot
}
#if ($MyInvocation.MyCommand.Definition -ne $null) {
#    $root = $MyInvocation.MyCommand.Definition
#}
$helpersPath = $root
@("Invoke-AsAdmin.ps1") |
    % { 
        $p = get-item "$root/functions/$_"
        . $p.fullname
    }



<#
.Synopsis 
"Writes the input to host output (using write-host) with added indentation"
.Parameter msg
Message to output
.Parameter level
Indentation level (default=2)
.Parameter mark
The marker for indented lines (default="> ")
.Parameter maxlen
Maximum line length - after which lines will be wrapped (also with indentation)
.Parameter passthru
Pass the input to the output
#>

function Write-Console {
    param($msg)
    if ($([Environment]::UserInteractive)) {
        write-host $msg #[$($msg.GetType().Name)]
    } else {
        write-verbose $msg -verbose #[$($msg.GetType().Name)]
    }
}

function Write-Indented 
{
    param(
        [Parameter(ValueFromPipeline=$true, Position=1, Mandatory=$true)]$msg, 
        [Parameter(Position=2)]$level = 2, 
        [Parameter(Position=3)]$mark = "> ", 
        [Parameter(Position=4)]$maxlen = $null, 
        [switch][bool]$passthru,
        [switch][bool]$timestamp,
        $timestampFormat = "yyyy-MM-dd HH:mm:ss.ff",
        [switch][bool]$passErrorStream
    )
    begin {
        $base_padding = $mark.PadLeft($level)
        if ($maxlen -eq $null) {
            $maxlen = 512
            if (([Environment]::UserInteractive) -and $host.UI.RawUI.WindowSize.Width -ne $null -and $host.UI.RawUI.WindowSize.Width -gt 0) {
                $maxlen = $host.UI.RawUI.WindowSize.Width - $level - 1
            }            
        }
        if (!$([Environment]::UserInteractive)) {
			write-warning "Write-Indented: non-UserInteractive console. will use verbose stream instead"
        }
    }
    process { 
        $msgs = @($msg)
        $pad = $base_padding
        if ($timestamp) {
            $pad = "[$(get-date -format)] $base_padding"
        }
        $msgs | % {     
            $PassToOutput = $passthru
			if ($_ -is [System.Management.Automation.ErrorRecord]) {
				$passToOutput = $passErrorStream
			}
            @($_.ToString().split("`n")) | % {
                $msg = $_
                $idx = 0    
                while($idx -lt $msg.length) {
                    $chunk = [System.Math]::Min($msg.length - $idx, $maxlen)
                    $chunk = [System.Math]::Max($chunk, 0)
                    write-console "$pad$($msg.substring($idx,$chunk))"                        
                    $idx += $chunk                    
                }
                if ($PassToOutput) {
                       write-output $msg
                }
            }
        }
    }
}

<#
.Synopsis
Invokes an external Command
.Parameter command
Command to invoke (either full path or filename)
.Parameter arguments
Arguments for the command
.Parameter nothrow
Do not throw if command's exit code != 0
.Parameter showoutput 
Write command output to host (default=true)
.Parameter silent
Do not rite command output to host (same as -showoutput:$false)
.Parameter passthru
Pass the command output to the output stream
.Parameter in
Input for the command (optional)
#>
function Invoke {
[CmdletBinding(DefaultParameterSetName="set1",SupportsShouldProcess=$true)]
param(
    [parameter(Mandatory=$true,ParameterSetName="set1", Position=1)]
    [parameter(Mandatory=$true,ParameterSetName="in",Position=1)]
    [parameter(Mandatory=$true,ParameterSetName="directcall",Position=1)]
    [string]$command,      
    [parameter(ParameterSetName="set1",Position=2)]
    [Parameter(ParameterSetName="in",Position=2)]
    [Alias("arguments")]
    [string[]]$argumentList, 
    [switch][bool]$nothrow, 
    [switch][bool]$showoutput = $true,
    [switch][bool]$silent,
    [switch][bool]$passthru,
    [switch][bool]$passErrorStream,
    [Parameter(ParameterSetName="in")]
    $in,
    [Parameter(ValueFromRemainingArguments=$true,ParameterSetName="in")]
    [Parameter(ValueFromRemainingArguments=$true,ParameterSetName="set1")]
    [Parameter(ValueFromRemainingArguments=$true,ParameterSetName="directcall")]
    $remainingArguments,
    [System.Text.Encoding] $encoding = $null,
    [switch][bool]$useShellExecute,
    [string[]]$stripFromLog
    ) 
    #write-verbose "argumentlist=$argumentList"
    #write-verbose "remainingargs=$remainingArguments"
    $arguments = @()

    function Strip-SensitiveData {
        param([Parameter(ValueFromPipeline=$true)]$str, [string[]]$tostrip)
        process {
            return @($_) | % {
                $r = $_ -replace "password[:=]\s*(.*?)($|[\s;,])","password={password_removed_from_log}`$2"
                if ($tostrip -ne $null) {
                    foreach($s in $tostrip) {
                        $r = $r.Replace($s,"{password_removed_from_log}")
                    }
                }
                $r
            } 
        }
    }

    if ($ArgumentList -ne $null) {
        $arguments += @($ArgumentList)
    }
    if ($remainingArguments -ne $null) {
        @($remainingArguments) | % {            
            $arguments += $_
        }
    }   
    if ($silent) { $showoutput = $false }
    $argstr = ""        
    $shortargstr = ""
    if ($arguments -ne $null) {         
        for($i = 0; $i -lt @($arguments).count; $i++) {
            $argstr += "[$i] $($arguments[$i] | Strip-SensitiveData -tostrip $stripFromLog)`r`n"
            $shortargstr += "$($arguments[$i] | Strip-SensitiveData -tostrip $stripFromLog) "
        } 
        write-verbose "Invoking: ""$command"" $shortargstr `r`nin '$($pwd.path)' arguments ($(@($arguments).count)):`r`n$argstr"
    }
    else {
        write-verbose "Invoking: ""$command"" with no args in '$($pwd.path)'"
    }
    
    
    if ($WhatIfPreference -eq $true) {
        write-warning "WhatIf specified. Not doing anything."
        return $null
    }

    try {
    if ($encoding -ne $null) {
        write-verbose "setting console encoding to $encoding"
        try {
            
            $oldEnc = [System.Console]::OutputEncoding
            [System.Console]::OutputEncoding = $encoding
        } catch {
            # caution: catching will still cause exception message to be logged to Error Stream
            write-warning "failed to set encoding to $encoding : $($_.Exception.Message)"
        }
    }
    if ($showoutput) {
        write-host "  ===== $command ====="
        if ($in -ne $null) {
            if ($useShellExecute) { throw "-UseShellExecute is not supported with -in" }
            $o = $in | & $command $arguments 2>&1 | write-indented -level 2 -passthru:$passthru -passErrorStream:$passErrorStream
        } else {
            if ($useShellExecute) {
                if ([System.IO.Path]::IsPathRooted($command) -or $command.Contains(" ")) { $command = """$command""" }
                $o = cmd /c "$command $shortargstr" 2>&1 | write-indented -level 2 -passthru:$passthru -passErrorStream:$passErrorStream
            } else {
                $o = & $command $arguments 2>&1	 | write-indented -level 2 -passthru:$passthru -passErrorStream:$passErrorStream
            }
        }
        
        write-host "  === END $command == ($lastexitcode)" 
    } else {
        if ($in -ne $null) {
            if ($useShellExecute) { throw "-UseShellExecute is not supported with -in" }
            if ($passErrorStream) {
                $o = $in | & $command $arguments  2>&1
            } else {
                # swallow error stream
                $o = $in | & $command $arguments 2>&1 | % { if ($_ -is [System.Management.Automation.ErrorRecord]) { } else { $_ } }
            }
        }
        else {
            if ($useShellExecute) {
                if ([System.IO.Path]::IsPathRooted($command) -or $command.Contains(" ")) { $command = """$command""" }
                if ($passErrorStream) {
                    $o = cmd /c "$command $shortargstr" 2>&1
                } else {
                    $o = cmd /c "$command $shortargstr" 2>&1 | % { if ($_ -is [System.Management.Automation.ErrorRecord]) { } else { $_ } }
                }
            } else {
                if ($passErrorStream) {
                    $o = & $command $arguments 2>&1
                } else {
                    $o = & $command $arguments 2>&1 | % { if ($_ -is [System.Management.Automation.ErrorRecord]) { } else { $_ } }
                }
            }
        }
    }
    } finally {
        if ($encoding -ne $null) {
            if ($oldEnc -ne $null) { 
                try {
                    [System.Console]::OutputEncoding = $oldEnc
                } catch {
                    write-warning "failed to set encoding back to $oldEnc : $($_.Exception.Message)"
                }
            }
        }
    }
    write-output $o
    if ($lastexitcode -ne 0) {
        write-verbose "invoke: ErrorActionPreference = $ErrorActionPreference"
        if (!$nothrow) {            
            write-error "Command $command returned $lastexitcode" 
            #$o | out-string | write-error
            throw "Command $command returned $lastexitcode" 
        } else {
           # $o | out-string | write-host 
           
        }
    }
}

<#
.Synopsis 
Checks if current process is running with elevation 
#>
function Test-IsAdmin() {
    return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
}

if ((get-alias Run-AsAdmin -ErrorAction ignore) -eq $null) { New-alias Run-AsAdmin Invoke-AsAdmin }
if ((get-alias sudo -ErrorAction ignore) -eq $null) { New-alias sudo Invoke-AsAdmin }

Export-ModuleMember -Function * -Alias *