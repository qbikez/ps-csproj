function import-sln($path) {
    if (!(test-path $path)) {
        throw "file not found: '$path'"
    }

    $content = get-content $path

    return @{
        originalpath = $path
        path = (get-item $path).FullName
        content = $content
    }
}

function get-slnprojects ($sln) {
    $result = @()
    # Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "Legimi.Core.Utils.Diag", "..\..\..\src\Core\Legimi.Core.Utils.Diag\Legimi.Core.Utils.Diag.csproj", "{678181A1-BF92-46F2-8D71-E3F5057042AB}"
    $regex = 'Project\((?<typeguid>.*?)\)\s*=\s*"(?<name>.*?)",\s*"(?<path>.*?)",\s*"(?<guid>.*?)"'
    $i = 0
    foreach($line in $sln.content) {
        if ($line -match $regex) {
            $result += @( new-object -type pscustomobject -Property @{ 
                name = $Matches["name"]
                path = $Matches["path"]
                guid = $Matches["guid"] 
                line = $i
            } )
        } 
        $i++   
    }
    
    $sln.projects = $result
    return $result
}

function find-slnproject($sln, $projectname) {
    if ($sln.projects -eq $null) { $sln.projects = get-slnprojects $sln }
    $proj = $sln.projects | ? { $_.name -ieq $projectname }
    return $proj
}

function remove-slnproject ($sln, $projectname) {
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