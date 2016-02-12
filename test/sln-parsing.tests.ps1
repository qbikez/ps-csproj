. $PSScriptRoot\includes.ps1
import-module csproj


Describe "parsing sln" {
    Context "when parsing sln projects" {
        $sln = import-sln "$inputdir\platform\sln\legimi.core\Legimi.Core.Utils\Legimi.Core.Utils.sln"
        It "Should return all projects" {
            $projects = get-slnprojects $sln
            $projects | format-table | out-string | log-info
            $projects | Should not benullorempty
        }
    }

     Context "when removing project from sln" {
        $sln = import-sln "$inputdir\platform\sln\legimi.core\Legimi.Core.Utils\Legimi.Core.Utils.sln"
        $oldprojects = get-slnprojects $sln

        It "sln Should not contain removed projects" {
            remove-slnproject $sln $oldprojects[0].Name
            $newprojects = get-slnprojects $sln
            $newprojects.Count | Should Be ($oldprojects.Count - 1)
        }
     }
}