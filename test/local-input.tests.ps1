. $PSScriptRoot\includes.ps1


Describe "Basic file parsing" {
    Context "When parsing csproj" {
        
        $dir = "$inputdir\Platform\src\Core\Legimi.Core.Utils"
        $csproj = import-csproj "$dir\Legimi.Core.Utils.csproj"
        It "should return a valid object" {
            $csproj | Should Not BeNullOrEmpty
        }

        It "should cointain project references" {
            $refs = get-allreferences $csproj
        
            log-info 
            log-info "Project references:"

            $refs | % {
                log-info $_.Node.OuterXml
            }      
            
            $refs.Count | Should Not Be 0
        }
    }
}