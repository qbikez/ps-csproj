import-module pester 

$artifacts = "$psscriptroot\..\artifacts"
if (!(Test-Path $artifacts)) {
    $null = new-item $artifacts -ItemType directory
}
$r = Invoke-Pester "$psscriptroot\..\test" -OutputFile "$artifacts\test-result.xml" -OutputFormat NUnitXml -EnableExit

return $r
