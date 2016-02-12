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
    
    foreach($line in $sln.content) {
        if ($line -match $regex) {
            $result += @( new-object -type pscustomobject -Property @{ name = $Matches["name"]; path = $Matches["path"]; guid = $Matches["guid"] } )
        }    
    }
    
    return $result
}

function remove-slnproject ($sln, $projectname) {
    throw "not implemented"
}