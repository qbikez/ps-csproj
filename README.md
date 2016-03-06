Installation
============

    Install-Module csproj
    
Usage
=====

Convert project references to nuget references
----------------------------------------------

1. Make sure the project you're trying to convert is installed as a nuget:

       nuget install "Project.To.Convert" -out "packages"

2. Convert all references to that projects:

       import-module csproj
       tonuget "path\to\my\solution.sln" -projectName "Project.To.Convert" -packagesDir "packages"

This will:
 * scan all `csproj` files referenced by `solution.sln`
 * replace all project references to `Project.To.Convert` with nuget references to `packages\Project.To.Convert.LatestVersion`
 * remove `Project.To.Convert` from `solution.sln` 
