function Get-NuspecVersion($nuspec = $null) {
	if ([string]::IsNullOrEmpty($nuspec)) {
		$nuspec = Get-ChildItem . -Filter *.nuspec | select -First 1
    }
    $content = Get-Content $nuspec
    $verRegex = "<version>(.*)</version>"
    [string]$line = $content | where { $_ -match $verRegex } | select -First 1
    $ver = $matches[1]
    return $ver
}

function Set-NuspecVersion([string] $version, $nuspec = $null) {
	if ($nuspec -eq $null) {
		$nuspec = Get-ChildItem . -Filter *.nuspec | select -First 1
    }
    $content = Get-Content $nuspec
    $content2 = $content | foreach { 
        if ($_ -match "<version>(.*)</version>") {       
            $_.Replace( $matches[0], "<version>$version</version>")
        } else {
            $_
        }
    }
    $content2 | Set-Content $nuspec     
}

function Incremet-NuspecVersion($nuspec = $null) {
	if ($nuspec -eq $null) {
		$nuspec = Get-ChildItem . -Filter *.nuspec | select -First 1
    }

    $ver = Get-NuspecVersion $nuspec
    
    $ver2 = Incremet-Version $ver
   
    Set-NuspecVersion -version $ver2 -nuspec $nuspec   
}
if (-not ([System.Management.Automation.PSTypeName]'VersionComponent').Type) {
Add-Type -TypeDefinition @"
   public enum VersionComponent
   {
      Major = 0,
      Minor = 1,
      Patch = 2
   }
"@
}

function Incremet-Version([Parameter(mandatory=$true)]$ver, [VersionComponent]$component = [VersionComponent]::Patch) {
     
    $vernums = $ver.Split(@('.','-'))
    $lastNumIdx = $component
    $lastNum = [int]::Parse($vernums[$lastNumIdx])
    
    <# for($i = $vernums.Count-1; $i -ge 0; $i--) {
        if ([int]::TryParse($vernums[$i], [ref] $lastNum)) {
            $lastNumIdx = $i
            break
        }
    }#>
    
    $lastNum++
    $vernums[$vernums.Count-1] = $lastNum.ToString()
    $ver2 = [string]::Join(".", $vernums)

    return $ver2
}