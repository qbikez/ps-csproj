
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
        SuffixBranch = 45,
        SuffixBuild = 50,
        SuffixRevision = 60
    }
   
    public class CustomSemVer : IComparable<CustomSemVer> {
        
        public string Suffix {get;set;}
        
        public string BranchName {get;set;}
        public int? BuildNum {get;set;}
        public string Revision {get;set;}

        public int[] VerNums {get;set;}
        public string RevSeparator {get;set;}

        public CustomSemVer() {

        }
        
        public int? GetComponent(VersionComponent c) {
            return VerNums.Length > (int)c ? VerNums[(int)c] : (int?)null;
        }
    
        public int? Major { get { return GetComponent(VersionComponent.Major); }}
        public int? Minor { get { return GetComponent(VersionComponent.Minor); }}
        public int? Patch { get { return GetComponent(VersionComponent.Patch); }}

        public string Version { get {
            return String.Join(".", VerNums);
        }}

        public override string ToString() {
            var s = Version;
            if (!string.IsNullOrEmpty(Suffix)) {
                s += "-" + Suffix;
            }
            return s;
        }
        
        public string FormatSuffix(bool compatibilityMode = false) {
            StringBuilder sb = new StringBuilder();
            if (!string.IsNullOrEmpty(BranchName)) {
                var b = BranchName;
                if (compatibilityMode) b = b.Replace("_","").Replace("+","").Replace(".","").Replace("/",""); // nuget does not tolerate these chars in suffix
                if (compatibilityMode) b = b.Substring(0, Math.Min(10,b.Length)); // max 20 chars for suffix: branch:10, build:3, rev:6, revseparator:1
                sb.Append(b);
            }
            if (BuildNum != null) {
                if (sb.Length == 0) {
                    sb.Append("build");
                }
                if (!compatibilityMode) sb.Append("."); // nuget does not tolerate `.` in suffix             
                if (sb.Length > 0 && Char.IsNumber(sb[sb.Length-1])) sb[sb.Length-1] = '-'; // separate branchname digits from build number
                sb.Append(BuildNum.Value.ToString("000"));
            }
            if (!string.IsNullOrEmpty(Revision)) {
                if (sb.Length > 0) {
                    var revsep = RevSeparator;
                    if (compatibilityMode) revsep = "-";
                    sb.Append(revsep);
                }
                var rev = Revision;
                if (compatibilityMode) rev = rev.Substring(0, Math.Min(6,rev.Length));
                sb.Append(rev);
            }
            
            return sb.ToString();
        }

        public int CompareTo(CustomSemVer other) {
            var major = this.Major.Value.CompareTo(other.Major.Value);
            if (major != 0) return major;
            var minor = this.Minor.Value.CompareTo(other.Minor.Value);
            if (minor != 0) return minor;
            var patch = this.Patch.Value.CompareTo(other.Patch.Value);
            if (patch != 0) return patch;

            return this.Suffix.CompareTo(other.Suffix);
        }
    }
"@
}

$buildSuffixRegex = "(\.|build){0,1}(?<buildno>[0-9]{3})($|[-+][a-fA-F0-9]+$)"

<#

.SYNOPSIS
Updates given component of a CustomSemVer string

.DESCRIPTION 

.PARAMETER ver 
CustomSemVer string 

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
        [Parameter(mandatory = $true)]$ver, 
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
        while ($lastNumIdx -gt ($semver.vernums.length - 1)) {
            write-verbose "$lastNumIdx > version length ($($semver.vernums.length-1)) => adding .0"
            $semver.vernums += @(0)
        }

        
          
        $lastNum = $semver.vernums[$lastNumIdx]
        
        if ($value -ne $null) {
            $lastNum = $value
        }
        else {
            $lastNum++
        }
        $semver.vernums[$component] = $lastNum.ToString()
        #each lesser component Should -Be set to 0 
        for ($i = [int]$component + 1; $i -lt $semver.vernums.length; $i++) {
            $semver.vernums[$i] = 0
        }
        if ($semver.BuildNum) {
            $ver2 = join-version $semver
            $ver2 = update-version $ver2 SuffixBuild -value 1 -compatibilityMode:$compatibilityMode
            return $ver2 
        } 
    }
    else {        
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
                $semver.buildnum = 1;
                #throw "suffix '$suffix' does not match $buildSuffixRegex pattern"
            }
        }
        if ($component -eq [VersionComponent]::SuffixRevision) {
            #write-verbose "setting suffix revision to '$value'"
            $revSeparator = "+"
            if ($compatibilityMode) { $revSeparator = "-" }
            $semver.RevSeparator = $revSeparator
            if (![string]::IsNullOrEmpty($semver.Revision)) {
                $oldrev = $semver.Revision
            }
            $semver.Revision = $value
        }
        if ($component -eq [VersionComponent]::SuffixBranch) {
            $semver.BranchName = $value
        }        
        $sfx = $semver.FormatSuffix($compatibilityMode)
        
        if ($component -eq [VersionComponent]::Suffix) {
            $sfx = $value
        }
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
    if ($suffix -match "^(?<branchname>[^.+]+)") {
        $branch = $matches["branchname"]
        if ($buildnumidx -ne $null -and $buildnumidx -gt 0) {
            $branch = $suffix.SubString(0, $buildnumidx)
        }
        elseif ($buildnumidx -eq 0) {
            $null = $suffix -match "^(?<branchname>[^.+\-0-9]+)"
            $branch = $matches["branchname"]
        }
    }
    $rev = $null
    $revSeparator = "+"
    if ($compatibilityMode) { $revSeparator = "-" }

    if ($suffix -match "\$revSeparator(?<rev>[a-fA-F0-9]+)$") {
        $rev = $Matches["rev"]
    }
   
    $r = new-object -type CustomSemVer -property @{
        Suffix       = $suffix    
        BuildNum     = $buildnum
        Revision     = $rev
        VerNums      = $vernums
        RevSeparator = $revSeparator
        BranchName   = $branch
    }
    return $r
}

function Join-Version([CustomSemVer] $version) {
    return $version.ToString()
}

new-alias increment-version update-version -force