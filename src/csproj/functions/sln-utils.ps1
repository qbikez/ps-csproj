$script:types = @"
public class Sln {
    public string OriginalPath {get;set;}
    public string Path {get;set;}
    public string[] Content {get;set;}
    public SlnProject[] projects {get;set;} 
}
public class SlnProject {
    public string Name {get;set;}
    public string Path {get;set;}
    public string Guid {get;set;}
    public int Line {get;set;}
    public string Type { get;set;} 
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
                line = $i
                type = $type
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

function remove-slnproject ([Sln]$sln, $projectname) {
    $proj = find-slnproject $sln $projectname
    if ($proj -eq $null) { throw "project '$projectname' not found in solution" }

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
    
    $newcontent = @()
    for($i = 0; $i -lt $sln.content.length; $i++) {
        if ($i -ge $proj.line -and $i -le $endi) { continue }
        else { $newcontent += $sln.content[$i] }
    }
    $sln.content = $newcontent
    $sln.projects = $sln.projects | ? { $_.name -ine $projectname }
}