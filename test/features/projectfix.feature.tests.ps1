Describe "fix a project with missing references" {
    Context "when initializing" {
        It "Should scan repo root for csproj files" {
            Set-TestInconclusive
        }
        It "Should scan packages dir for nuget packages" {
            Set-TestInconclusive
        }
        It "Should scan chosen packages source for nuget packages"{
            Set-TestInconclusive
        }
    }
    Context "When a matching csproj can be found in repo directory"{
        It "Should replace reference path with a valid csproj" {
            Set-TestInconclusive
        }
    }
    Context "When a matching nuget can be found in one of the sources" {
        It "Should repace reference with a valid nuget" {
            Set-TestInconclusive
        }
    }
}