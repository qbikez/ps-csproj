. "$PSScriptRoot\includes.ps1"
import-module process

Describe "Process module tests" {
    It "Should invoke process" {
        invoke echoargs
    }
    <#It "Should throw on missing command" {
        { invoke "not-found.exe" } | should throw
    }#>
    It "Should pass all direct arguments" {
        $r = invoke echoargs -a=1 -b 2 -e="1 2" -passthru -verbose | out-string
        $expected = @"
Arg 0 is <-a=1>
Arg 1 is <-b>
Arg 2 is <2>
Arg 3 is <-e=1 2>
Command line:
"c:\tools\chocolatey\lib\echoargs\tools\EchoArgs.exe" -a=1 -b 2 "-e=1 2"

"@
        $r | Should Be $expected

    }
     
    It "Should pass array arguments" {
        $a = @(
            "-a=1"
            "-b"
            "2"
            "-e=1 2"
        )
        $r = invoke echoargs -arguments $a -passthru | out-string
        $expected = @"
Arg 0 is <-a=1>
Arg 1 is <-b>
Arg 2 is <2>
Arg 3 is <-e=1 2>
Command line:
"c:\tools\chocolatey\lib\echoargs\tools\EchoArgs.exe" -a=1 -b 2 "-e=1 2"

"@
        $r | Should Be $expected

    }
    It "Should pass array args whith double quotes" {
        $a = @(
            "-a=1"
            "-b"
            "2"
            "-e=`"1 2`""
        )
        $r = invoke echoargs -arguments $a -passthru | out-string
        $expected = @"
Arg 0 is <-a=1>
Arg 1 is <-b>
Arg 2 is <2>
Arg 3 is <-e=1 2>
Command line:
"c:\tools\chocolatey\lib\echoargs\tools\EchoArgs.exe" -a=1 -b 2 -e="1 2"

"@
        $r | Should Be $expected

    }
    It "Should pass array args by position" {
        $a = @(
            "-a=1"
            "-b"
            "2"
        )
        $r = invoke echoargs $a -passthru | out-string
        $expected = @"
Arg 0 is <-a=1>
Arg 1 is <-b>
Arg 2 is <2>
Command line:
"c:\tools\chocolatey\lib\echoargs\tools\EchoArgs.exe" -a=1 -b 2

"@
        $r | Should Be $expected

    }
}