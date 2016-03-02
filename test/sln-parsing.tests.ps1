. $PSScriptRoot\includes.ps1
import-module csproj


Describe "parsing sln" {
    Context "when parsing sln projects" {
        $sln = import-sln "$inputdir\platform\sln\legimi.core\Legimi.Core.Utils\Legimi.Core.Utils.sln"
        $projects = get-slnprojects $sln
            
        It "Should return all projects" {
            #$projects | format-table | out-string | log-info
            $projects | Should not benullorempty
        }
        It "Should contain Legimi.Core.Utils" {
            $p = $projects | ? { $_.Name -eq "Legimi.Core.Utils" }
            $p | Should Not BeNullorempty
            $p.type | Should Be "csproj"
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
     
     Context "When updating project in sln" {
        $sln = import-sln "$inputdir\platform\sln\legimi.core\Legimi.Core.Utils\Legimi.Core.Utils.sln"
        $oldprojects = get-slnprojects $sln
        It "sln Should contain updated projects" {
            $oldprojects[0].Name = "Something.New"
            update-slnproject $sln $oldprojects[0]
            $newprojects = get-slnprojects $sln
            $newprojects.Count | Should Be ($oldprojects.Count)
            $newprojects[0].Name | Should Be "Something.New"
        }        
     }
}