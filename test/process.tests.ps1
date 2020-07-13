BeforeAll {
    . "$PSScriptRoot\includes.ps1"
    if ((gmo process) -ne $null) { rmo process -Force }

    import-module $PSScriptRoot\..\src\process\process.psm1

    $echoargs = "$psscriptroot\tools\powerecho\bin\Debug\netcoreapp1.1\win10-x64\powerecho.exe"
    $echoargs = [System.IO.Path]::GetFullPath($echoargs)
}

Describe "Processing output from invoke" {
    It "long messages does not break output" {
        $msg = "this is my very long line afsdfggert345v w35 34tesw23523r w4fgset q25r tsdfgzsw5312rfsdf awer sef ser waq324 123rfwefszer t235r 312gergt324w5 fsdf ds f sdf sdf sdf dsf esf sdf ds"
        $r = invoke $echoargs "--return" $msg --log stderr -passthru -showoutput:$true
        $r | Should -Be $msg
    }
    It "newline should cause result split" {
        $error.clear()
        $msg = "this is my `nresult"
        $r = invoke $echoargs "--return" $msg --log stderr -passthru -showoutput:$true
        $r.count | Should -Be 2
        $r[0] | Should -Be "this is my "
        $r[1] | Should -Be "result"
    }
    It "Should ignore command output when passthru=false" {
        $msg = "this is my result"
        $r = invoke $echoargs "--return" $msg --log null
        $r | Should -BeNullOrEmpty
    }
    It "Should return only stdout when logging to null" {
        $msg = "this is my result"
        $r = invoke $echoargs "--return" $msg --log null -passthru
        $r | Should -Be $msg
    }
    It "Should return only stdout when logging to stderr" {
        $msg = "this is my result"
        $r = invoke $echoargs "--return" $msg --log stderr -passthru
        $r | Should -Be $msg
    }
    It "Should fill error stream when showoutput=false" {
        $error.clear()
        $msg = "this is my result"
        $r = invoke $echoargs "--return" $msg --log stderr -passthru -showoutput:$false
        $r | Should -Be $msg
        if ($error.count -gt 0) {
            $i = 0
            $error | % { write-verbose "ERROR[$($i)]: $_" -Verbose; $i++; }
        }
        # expect 3 lines of log in stderr:
        # powerecho.exe > verbose: using stderr for log output
        # powerecho.exe > verbose: will return 'this is my result'
        # powerecho.exe > verbose: Power echo here! Args:
        $error.count | Should -Be 3
    }
    It "Should not duplicate output when showoutput=true" {
        $msg = "this is my result"
        $r = invoke $echoargs "--return" $msg --log stderr -passthru -showoutput:$true
        $r | Should -Be $msg
    }
 
      It "Should not write errors to console when showoutput=false" {
        $error.clear()
        $msg = "this is my result"
        $r = invoke $echoargs "--return" $msg --log stderr -passthru -showoutput:$false
        $r | Should -Be $msg
        # HOW to test this??
    }
}

Describe "Passing arguments from invoke" {
    # init - download echoargs
    
   
    #It "Should throw on missing command" {
    #    { invoke "not-found.exe" } | should throw
    # }

    It "Should pass all direct arguments quoted 1" {
        $r = invoke $echoargs test -a=1 -b 2 -e="1 2" -passthru -verbose | out-string | % { $_ -replace "`r`n","`n" }
        $expected = @"
Arg 0 is <test>
Arg 1 is <-a=1>
Arg 2 is <-b>
Arg 3 is <2>
Arg 4 is <-e=1 2>
Command line:
"$echoargs" test -a=1 -b 2 "-e=1 2"

"@ | % { $_ -replace "`r`n","`n" }
        $r | Should -Be $expected

    }

     It "Should pass all direct arguments quoted 2" {
        $r = invoke $echoargs -a=1 -b=2 -e="1 2" -passthru  -verbose | out-string | % { $_ -replace "`r`n","`n" }
        $expected = @"
Arg 0 is <-a=1>
Arg 1 is <-b=2>
Arg 2 is <-e=1 2>
Command line:
"$echoargs" -a=1 -b=2 "-e=1 2"

"@ | % { $_ -replace "`r`n","`n" }
        $r | Should -Be $expected

    }

     It "Should pass all direct arguments quoted 3" {
        $r = invoke $echoargs -a=1 -b 2 -e="1 2" -passthru -verbose | out-string | % { $_ -replace "`r`n","`n" }
        $expected = @"
Arg 0 is <-e=1 2>
Arg 1 is <-a=1>
Arg 2 is <-b>
Arg 3 is <2>
Command line:
"$echoargs" "-e=1 2" -a=1 -b 2

"@ | % { $_ -replace "`r`n","`n" }
        $r | Should -Be $expected

    }

     It "Should pass all direct arguments" {
        $r = invoke $echoargs -a=1 -b 2 -e=1 -passthru -verbose | out-string | % { $_ -replace "`r`n","`n" }
        $expected = @"
Arg 0 is <-a=1>
Arg 1 is <-b>
Arg 2 is <2>
Arg 3 is <-e=1>
Command line:
"$echoargs" -a=1 -b 2 -e=1

"@ | % { $_ -replace "`r`n","`n" }
        $r | Should -Be $expected

    }
     
    It "Should pass array arguments" {
        $a = @(
            "-a=1"
            "-b"
            "2"
            "-e=1 2"
        )
        $r = invoke $echoargs -argumentList $a -passthru | out-string  | % { $_ -replace "`r`n","`n" }
        $expected = @"
Arg 0 is <-a=1>
Arg 1 is <-b>
Arg 2 is <2>
Arg 3 is <-e=1 2>
Command line:
"$echoargs" -a=1 -b 2 "-e=1 2"

"@ | % { $_ -replace "`r`n","`n" }
        $r | Should -Be $expected

    }
    It "Should pass array args whith double quotes" {
        $a = @(
            "-a=1"
            "-b"
            "2"
            "-e=`"1 2`""
        )
        $r = invoke $echoargs -arguments $a -passthru | out-string  | % { $_ -replace "`r`n","`n" }
        $expected = @"
Arg 0 is <-a=1>
Arg 1 is <-b>
Arg 2 is <2>
Arg 3 is <-e=1 2>
Command line:
"$echoargs" -a=1 -b 2 "-e=1 2"

"@  | % { $_ -replace "`r`n","`n" }
        $r | Should -Be $expected

    }
    It "Should pass array args by position" {
        $a = @(
            "-a=1"
            "-b"
            "2"
        )
        $r = invoke $echoargs $a -passthru | out-string  | % { $_ -replace "`r`n","`n" }
        $expected = @"
Arg 0 is <-a=1>
Arg 1 is <-b>
Arg 2 is <2>
Command line:
"$echoargs" -a=1 -b 2

"@  | % { $_ -replace "`r`n","`n" }
        $r | Should -Be $expected

    }
}

Describe "check echoargs" {
    It "Should invoke echoargs" {
        invoke $echoargs
    }
}
