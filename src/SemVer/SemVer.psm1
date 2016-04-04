
if (-not ([System.Management.Automation.PSTypeName]'VersionComponent').Type) {
Add-Type -TypeDefinition @"
   using System;
   using System.Text;
   public enum VersionComponent
   {
      Major = 0,
      Minor = 1,
      Patch = 2,
      Build = 3,
      Suffix = 4,
      SuffixBuild = 50,
      SuffixRevision = 60
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
     
     public string BranchName {get;set;}
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
     
     public string FormatSuffix() {
         StringBuilder sb = new StringBuilder();
         if (!string.IsNullOrEmpty(BranchName)) {
             sb.Append(BranchName);
         }
         if (BuildNum != null) {
             if (sb.Length == 0) {
                 sb.Append("build");
             }
             sb.Append(".").Append(BuildNum.Value.ToString("000"));
         }
         if (!string.IsNullOrEmpty(Revision)) {
             if (sb.Length > 0) {
                 sb.Append(RevSeparator);
             }
             sb.Append(Revision);
         }
         
         return sb.ToString();
     }
   }
"@
}

$buildSuffixRegex = "(\.|build)(?<buildno>[0-9]{3})"

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
    [CmdletBinding()]
    param(
        [Parameter(mandatory=$true)]$ver, 
        [VersionComponent]$component = [VersionComponent]::Patch, 
        $value = $null,
        [Alias("nuget")]
        [switch][bool] $compatibilityMode
        ) 
        
    write-verbose "updating version $ver component $component to value $value"
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
            $semver.buildnum = 0
        }        
        if ($component -eq [VersionComponent]::SuffixBuild) {
            if ($semver.buildnum -ne $null) {
                if ($value -ne $null) {
                    $semver.buildnum = $value
                }
                else {
                    $semver.buildnum++
                }
            }
            else {
                throw "suffix '$suffix' does not match $buildSuffixRegex pattern"
            }
        }
        if ($component -eq [VersionComponent]::SuffixRevision) {
            #write-verbose "setting suffix revision to '$value'"
            $revSeparator = "+"
            if ($compatibilityMode) { $revSeparator = "-" }
            $semver.RevSeparator = $revSeparator
            if (![string]::IsNullOrEmpty($semver.Revision)) {
                $oldrev = $semver.Revision
                $semver.Revision = $value
            }
            else {
            }
        }
        $sfx = $semver.FormatSuffix()
        write-verbose "updating suffix $($semver.suffix) => $sfx"
        $semver.suffix = $sfx
    }
    
    $ver2 = $semver.ToString()
    return $ver2
}

function Split-Version($ver, [switch][bool] $compatibilityMode) {
    $null = $ver -match "(?<version>[0-9]+(\.[0-9]+)*)(-(?<suffix>.*)){0,1}"
    $version = $matches["version"]
    $suffix = $matches["suffix"]
    if ([string]::isnullorempty($suffix)) { $suffix = $null }
    
    $vernums = @($version.Split(@('.')))
    $vernums = $vernums | % { [int]$_ }
    
    $buildnum = $null
    $buildnumidx = $null
    if ($suffix -match $buildSuffixRegex) {
        $m = [regex]::match($suffix, $buildSuffixRegex)
        $buildnumidx = $m.Index
        $buildnum = [int]$matches["buildno"]
        $suffixbuild = ".$($buildnum.ToString("000"))"
    }
    if ($suffix -match "^(?<branchname>[^.\-0-9]+)") {
        $branch = $matches["branchname"]
        if ($buildnumidx -ne $null -and $buildnumidx -gt 0) {
            $branch = $suffix.SubString(0,$buildnumidx)
        }
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
        BranchName = $branch
    }
    return $r
}

function Join-Version([SemVer] $version) {
    return $version.ToString()
}

new-alias increment-version update-version