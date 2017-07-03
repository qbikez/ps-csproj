
<#
.Synopsis
Start the given program as administrator (elevated)
If the current process is elevated, just executes the command (using "start-process")
.Parameter argumentlist
Argument list for the started program
.Parameter proc
The program to start (default=powershell)
.Parameter wait
Wait for the elevated command to finish before continuing (default=true)
#>
function Invoke-AsAdmin($ArgumentList, $proc = "powershell", [switch][bool] $Wait = $true, [switch][bool] $NoExit = $false) {	
    if (!(test-IsAdmin)) {      
        if ($NoExit) {
            $argumentList = @("-NoExit") +  @($argumentList) 
        }
        Start-Process $proc -Verb runAs -ArgumentList $ArgumentList -wait:$Wait 
    }
    else {
        # this is a workaround  for doublequote problem
        if ($false -and ($proc -eq "powershell") -and ($ArgumentList.Length -eq 2) -and ($ArgumentList[0] -eq "-Command")) {
            $tmppath = "$env:TEMP\tmp.ps1"
            $argumentList[1] | Out-File $tmppath -Encoding utf8 -Force 
            & $proc $tmppath | out-default
        }
        else { 
            & $proc $ArgumentList | out-default
        }
    }
}
