# Adds BeforeAll at the top of Tests file to make it follow Pester v5 recommendation of putting
# all code into Pester controlled blocks.

# DO this:
#  BeforeAll {
#     . $PSScriptRoot/Code.ps1
# }

# DO this:
#  BeforeAll {
#     . $PSCommandPath.Replace('.Tests.', '')
# }



# DON'T do this:
# . $PSScriptRoot/Code.ps1

# DON'T do this:
# . $here/$sut

# DON'T do this:
#  BeforeAll {
#     . ($MyInvocation.MyCommand.Path | Split-Path)/Code.ps1
# }

# 🔥 it is highly encouraged to backup your solution first, or use git.

param (
    [Parameter(Mandatory=$false)]
    # Path to be recursively searched for *.Tests.ps1
    [String[]] $Path = ".",
    # Excluded paths using -like wildcards
    [String[]] $Exclude = @(),
    [String] $Filter = "*.Tests.ps1",
    [String] $Margin = " " * 4,
    [String] $Encoding = "UTF8"
)

$files = Get-ChildItem $Path -Recurse -Filter *.Tests.ps1 |
    where { $fullName = $_.FullName; -not ($Exclude | where { $_ -like $fullName })}

foreach ($f in $files) {
    $fullName = $f.FullName
    $beforeAllFound = $false
    $describeFound = $false
    $setupFound = $false
    $lines = (Get-Content $fullName -Encoding UTF8)

    $i = 0
    foreach ($line in $lines) {
        if ($line -match "BeforeAll\s*{") {
            $beforeAllFound = $true
            break
        }

        if ($line -match "^\s*(Describe|Context)\s*[-""'{]") {
            $describeFound = $true
            break
        }

        if (-not [string]::IsNullOrWhiteSpace($line) -and $line -notmatch "^\s*#") {
            $setupFound = $true
        }

        $i++
    }

    if ($beforeAllFound) {
        Write-Verbose "Found BeforeAll at the start of file, skipping. '$fullName'"
        continue
    }

    if (-not $describeFound -or -not $setupFound) {
        Write-Verbose "Found Describe or Context but no code at the start of file, skipping. '$fullName'"
        continue
    }

    Write-Verbose "There are $i lines of setup before Describe or Context. '$fullName'"

    $setupLines = $lines[0..($i - 1)]
    for ($c = 0; $c -lt $setupLines.Length; $c++) {
        if (-not [string]::IsNullOrWhiteSpace($setupLines[$c]) -and $setupLines[$c] -notmatch "^\s*#") {
            break
        }
        Write-Verbose "'$($setupLines[$c])' is a comment or empty line. '$fullName'"
    }

    $start = 0
    $commentLines = @()
    if ($c -gt 0) {
        $commentLines = @($setupLines[0..($c-1)])
        $start = $c
    }

    $setupLines = @($lines[$start..($i - 1)])

    for ($e = $setupLines.Length - 1; $e -ge 0; $e--) {
        if (-not [string]::IsNullOrWhiteSpace($setupLines[$e])) {
            break
        }
    }

    $setupLinesWithoutEmptyEnd = $setupLines[0..$e]
    $formatted = foreach ($line in $setupLinesWithoutEmptyEnd) {
        if ($line -like '"@*' -or $line -like "'@*") {
            # don't move here-strings terminators
            $line
        }
        elseif (-not [string]::IsNullOrWhiteSpace($line)) {
            "$Margin$line"
        }
        else {
            ""
        }
    }

    $linesWithBeforeAll = $($commentLines) + @("BeforeAll {") + @($formatted) + @("}", "") + @($lines[$i..($lines.Length - 1)])
    $linesWithBeforeAll -join [Environment]::NewLine | Set-Content $f.FullName -Encoding UTF8 -NoNewLine
}