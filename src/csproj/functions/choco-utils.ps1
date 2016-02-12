# taken from chocolatey

function Get-PackageFoldersForPackage {
param(
  [string]$packageName = '',
  $packagesDir
)
  return Get-ChildItem $packagesDir | ?{$_.name -match "^$packageName\.\d+"}
}

function Get-LongPackageVersion {
param(
  [string] $packageVersion = ''
)
  $longVersion = $packageVersion.Split('-')[0].Split('.') | %{('0' * (12 - $_.Length)) + $_}
  
  $longVersionReturn = [System.String]::Join('.',$longVersion)
  
  if ($packageVersion.Contains('-')) {
    $prerelease = $packageVersion.Substring($packageVersion.IndexOf('-') + 1)
    $longVersionReturn += ".$($prerelease)"
  }

  Write-Debug "Long version of $packageVersion is `'$longVersionReturn`'"
  
  return $longVersionReturn
}

function Get-VersionsForComparison {
param (
  $packageVersions = @()
)

  $versionsForComparison = @{}
  foreach ($packageVersion in $packageVersions) {
    $longVersion = Get-LongPackageVersion $packageVersion
    if ($versionsForComparison.ContainsKey($longVersion) -ne $true) {
      $versionsForComparison.Add($longVersion,$packageVersion)
    }
    
  } 
  
  return $versionsForComparison
}

function Get-PackageFolderVersions {
param(
  [string] $packageName = '',
  $packagesDir
)

  $packageFolders = Get-PackageFoldersForPackage $packageName $packagesDir
  $packageVersions = @()
  foreach ($packageFolder in $packageFolders) {
    $packageVersions = $packageVersions + $packageFolder.Name -replace "$packageName\."
  }
 
  return Get-VersionsForComparison $packageVersions
}

function Get-LatestPackageVersion {
param(
  $packageVersions = @()
)
  $latestVersion = ''
  if ($packageVersions -ne $null -and $packageVersions.GetEnumerator() -ne $null) {
    $packageVersions = $packageVersions.GetEnumerator() | sort-object -property Name -descending
    if ($packageVersions -is [Object[]]) {
      $latestPackageVersion = $packageVersions.GetEnumerator() | Select-Object -First 1
      Write-Debug "Using $($latestPackageVersion.Value) as the latest version (from multiple found versions)"
      $latestVersion = $latestPackageVersion.Value
    }
  else {
    Write-Debug "Using $($packageversions.value) as the latest version"
    $latestversion=$packageversions.value
  }
  }

  return $latestVersion
}