
if (-not ([System.Management.Automation.PSTypeName]'VersionComponent').Type) {
Add-Type -TypeDefinition @"
   using System;
   public enum VersionComponent
   {
      Major = 0,
      Minor = 1,
      Patch = 2,
      Build = 3,
      Suffix = 4,
      SuffixBuild = 5,
      SuffixRevision = 6
   }
   
   public class SemVer {
     public int? GetComponent(VersionComponent c) {
         return VerNums.Length > (int)c ? VerNums[(int)c] : (int?)null;
     }
     public int? Major { get { return GetComponent(VersionComponent.Major); }}
     public int? Minor { get { return GetComponent(VersionComponent.Minor); }}
     public int? Patch { get { return GetComponent(VersionComponent.Patch); }}
     
     public string Version { get {
         return String.Join(".", VerNums);
     }}
     public string Suffix {get;set;}
     public int? BuildNum {get;set;}
     public string Revision {get;set;}

     public int[] VerNums {get;set;}
     public string RevSeparator {get;set;}
     
     public override string ToString() {
         var s = Version;
         if (!string.IsNullOrEmpty(Suffix)) {
             s += "-" + Suffix;
         }
         return s;
     }
   }
"@
}


<#

.SYNOPSIS
Updates given component of a SemVer string

.DESCRIPTION 

.PARAMETER ver 
SemVer string 

.PARAMETER component
The version component you wish to update (Major, Minor, Patch)
Also supports prerelease data with (SuffixBuild) and (SuffixRevision) 

.PARAMETER value
Value for the specified version component. If value is not provided, the function will increment current number

.PARAMETER compatibilityMode
Use compatibility mode (useful for working with nuget packages) 

.EXAMPLE 
Update-Version "1.0.1" Patch 
1.0.2
Increment Patch component of version 1.0.1

.NOTES

.LINK

#>
function Update-Version {
    param(
        [Parameter(mandatory=$true)]$ver, 
        [VersionComponent]$component = [VersionComponent]::Patch, 
        $value = $null,
        [Alias("nuget")]
        [switch][bool] $compatibilityMode
        ) 
    $semver = split-version $ver -compatibilityMode:$compatibilityMode
    $suffix = $semver.Suffix    
    
    $lastNumIdx = $component
    if ($component -lt [VersionComponent]::Suffix) {
        $lastNum = $semver.vernums[$lastNumIdx]
        
        if ($value -ne $null) {
            $lastNum = $value
        }
        else {
            $lastNum++
        }
        $semver.vernums[$component] = $lastNum.ToString()
        #each lesser component should be set to 0 
        for($i = [int]$component + 1; $i -lt $semver.vernums.length; $i++) {
            $semver.vernums[$i] = 0
        }
        if ($semver.BuildNum) {
             $ver2 = join-version $semver
             $ver2 = update-version $ver2 SuffixBuild -value 1
             return $ver2 
        } 
    } else {
        if ([string]::IsNullOrEmpty($suffix)) {
            #throw "version '$ver' has no suffix"
            $suffix = "build000"
        }
        
        if ($component -eq [VersionComponent]::SuffixBuild) {
            if ($semver.buildnum -ne $null) {
                if ($value -ne $null) {
                    $semver.buildnum = $value
                }
                else {
                    $semver.buildnum++
                }
                $suffix = $suffix -replace "build[0-9]+","build$($semver.buildnum.ToString("000"))"
                $semver.suffix = $suffix
            }
            else {
                throw "suffix '$suffix' does not match build[0-9] pattern"
            }
        }
        if ($component -eq [VersionComponent]::SuffixRevision) {
            $revSeparator = "+"
            if ($compatibilityMode) { $revSeparator = "-" }

            if ($semver.Revision -ne $null) {
                $oldrev = $semver.Revision
                $semver.Revision = $value
                $suffix = $suffix -replace "\$($semver.RevSeparator)$oldrev","$revSeparator$value"
            }
            else {
                $suffix = $suffix + "$revSeparator$value"
            }
            $semver.suffix = $suffix
        }
    }
    
    $ver2 = $semver.ToString()
    return $ver2
}

function Split-Version($version, [switch][bool] $compatibilityMode) {
    $null = $ver -match "(?<version>[0-9]+(\.[0-9]+)*)(-(?<suffix>.*)){0,1}"
    $version = $matches["version"]
    $suffix = $matches["suffix"]
    if ([string]::isnullorempty($suffix)) { $suffix = $null }
    
    $vernums = @($version.Split(@('.')))
    $vernums = $vernums | % { [int]$_ }
    
    $buildnum = $null
    if ($suffix -match "build([0-9]+)") {
        $buildnum = [int]$matches[1]
        $suffixbuild = "build$buildnum"
    }
    $rev = $null
    $revSeparator = "+"
    if ($compatibilityMode) { $revSeparator = "-" }

    if ($suffix -match "\$revSeparator(?<rev>[a-fA-F0-9]+)$") {
        $rev = $Matches["rev"]
    }
   
    $r = new-object -type SemVer -property @{
        Suffix = $suffix    
        BuildNum = $buildnum
        Revision = $rev
        VerNums = $vernums
        RevSeparator = $revSeparator
    }
    return $r
}

function Join-Version([SemVer] $version) {
    return $version.ToString()
}

new-alias increment-version update-version