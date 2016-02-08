function ExitWithCode 
{ 
    param 
    ( 
        $exitcode 
    )

    $host.SetShouldExit($exitcode) 
    exit 
}

$artifacts = "$psscriptroot\..\artifacts"

try {
if (test-path "$artifacts\test-result.xml") {
    remove-item "$artifacts\test-result.xml"
}

$testResultCode = & "$PSScriptRoot\test.ps1"

if (!(test-path "$artifacts\test-result.xml")) {
    throw "test results not found at $artifacts\test-result.xml!"
}

$content = get-content "$artifacts\test-result.xml" | out-string
if ([string]::isnullorwhitespace($content)) {
    throw "$artifacts\test-result.xml is empty!"
}

$url = "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)"
#$url = https://ci.appveyor.com/api/testresults/nunit/bq558ckwevwb47qb
write-host "uploading test result to $url"
# upload results to AppVeyor
$wc = New-Object 'System.Net.WebClient'

try {
    $r = $wc.UploadFile($url, ("$artifacts\test-result.xml"))
    
write-host "upload done. result = $r"
} 
finally {
    $wc.Dispose()
}
write-host "pester result = '$testResultCode' lastexitcode=$lastexitcode"

#ExitWithCode $testResultCode

} catch {
    ExitWithCode 1  
}
