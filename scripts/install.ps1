[CmdletBinding(SupportsShouldProcess=$true)]
param($modulename = "csproj") 

$path = "C:\Program Files\WindowsPowershell\Modules\$modulename"
$target = "$PSScriptRoot\..\src\$modulename"
$target = (get-item $target).FullName

if (test-path $path) {
    if ($PSCmdlet.ShouldProcess("removing path $path")) {
        remove-item -Recurse $path
    }
}
write-host "executing mklink /J $path $target"
cmd /C "mklink /J ""$path"" ""$target"""