$script:types = @"
public class Sln {
    public string OriginalPath {get;set;}
    public string Path {get;set;}
    public string Fullname { get { return Path; }}
    public string[] Content {get;set;}
    public SlnProject[] projects {get;set;} 
    
    public void Save() {
        System.IO.File.WriteAllLines(Fullname, Content);
    }
}
public class SlnProject {
    public string Name {get;set;}
    public string Path {get;set;}
    public string Guid {get;set;}
    public int Line {get;set;}
    public string Type { get;set;} 
    public string FullName {get;set;}
    public string TypeGuid {get;set;}
    
    public override string ToString() {
        return Name;
    }
    
  
}
"@

add-type -TypeDefinition $types

function import-sln {
    [OutputType([Sln])]
    param($path)
    
    if (!(test-path $path)) {
        throw "file not found: '$path'"
    }

    $content = get-content $path

    $sln = new-object -type "sln" 
    
    $sln.originalpath = $path
    $sln.path = (get-item $path).FullName
    $sln.content = $content
    
    return $sln
}

function get-slnprojects {
    [OutputType([SlnProject[]])] 
    param([Parameter(ValueFromPipeline=$true)][Sln]$sln) 
    
    $result = @()
    # Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "Legimi.Core.Utils.Diag", "..\..\..\src\Core\Legimi.Core.Utils.Diag\Legimi.Core.Utils.Diag.csproj", "{678181A1-BF92-46F2-8D71-E3F5057042AB}"
    $regex = 'Project\((?<typeguid>.*?)\)\s*=\s*"(?<name>.*?)",\s*"(?<path>.*?)",\s*"(?<guid>.*?)"'
    $i = 0
    $slndir = (get-item (split-path -parent $sln.path)).fullname
    foreach($line in $sln.content) {
        if ($line -match $regex) {
            $type = "?"
            if ([System.io.path]::GetExtension($Matches["path"]) -eq ".csproj") {
                $type = "csproj"
            }
            $result += @( new-object -type SlnProject -Property @{ 
                name = $Matches["name"]
                path = $Matches["path"]
                guid = $Matches["guid"] 
                typeguid = $matches["typeguid"]
                line = $i
                type = $type
                fullname = join-path $slndir $Matches["path"]
            } )
        } 
        $i++   
    }
    
    $sln.projects = $result
    return $result
}

function find-slnproject { 
    [OutputType([SlnProject])]
    param ([Sln]$sln, [string]$projectname) 
    if ($sln.projects -eq $null) { $sln.projects = get-slnprojects $sln }
    $proj = $sln.projects | ? { $_.name -ieq $projectname }
    return $proj
}

function Update-SlnProject {
[CmdletBinding()]
param([Sln]$sln, [SlnProject] $project) 
      # Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "Legimi.Core.Utils.Diag", "..\..\..\src\Core\Legimi.Core.Utils.Diag\Legimi.Core.Utils.Diag.csproj", "{678181A1-BF92-46F2-8D71-E3F5057042AB}"
   $regex = 'Project\((?<typeguid>.*?)\)\s*=\s*"(?<name>.*?)",\s*"(?<path>.*?)",\s*"(?<guid>.*?)"'
   $line = "Project($($project.typeguid)) = ""$($project.Name)"", ""$($project.Path)"", ""$($project.guid)"""
   write-verbose "replacing line:"
   write-verbose "$($sln.content[$project.line])"
   write-verbose "=> $line"
   $sln.content[$project.line] = $sln.content[$project.line] -replace $regex,$line 
}

function remove-slnproject {
[CmdletBinding()]    
param ([Sln]$sln, $projectname, [switch][bool] $ifexists) 
    $proj = find-slnproject $sln $projectname
    if ($proj -eq $null) { 
        if ($ifexists) {
            return
        } else {
            throw "project '$projectname' not found in solution"
        } 
    }

    $regex = "EndProject"    
    $endi = -1
    for($i = $proj.line; $i -lt $sln.content.length; $i++) {
        $line = $sln.content[$i]
        if ($line -match $regex) {
            $endi = $i
            break;
        }
    }
    
    
    
    if ($endi -eq -1) { throw "failed to find line matching /$regex/"}
    
    $newcontent = new-object -type "System.Collections.ArrayList"
    for($i = 0; $i -lt $sln.content.length; $i++) {
        if ($i -ge $proj.line -and $i -le $endi) { 
            continue 
        }
        else { 
            $null = $newcontent.Add($sln.content[$i]) 
        }
    }
    
    $referencingLines = @()
    for($i = 0; $i -lt $newcontent.Count; $i++) {
        if ($newcontent[$i] -match "$($proj.Guid)") {
            $referencingLines += @{ line = $i; text = $newcontent[$i] }
        }
    }
    
    for ($i = $referencingLines.length - 1; $i -ge 0; $i--) {
        write-verbose "Removing referencing line $($referencingLines[$i].line): $($referencingLines[$i].text)"
        $null = $newcontent.RemoveAt($referencingLines[$i].line)
    }
        
    $sln.content = @() + $newcontent
    $sln.projects = get-slnprojects $sln
    
    return
}