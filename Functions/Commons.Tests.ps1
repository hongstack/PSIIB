InModuleScope PSIIB {
    Describe "IIB Home configuration" -Tags ('Commons', 'IIBHome') {
        Context "IIBHome setting" {
            It "Throws exception when IIBHome does not exist" {
                $IIBHome = 'A directory that does not exist'
                {Set-IIBHome -IIBHome $IIBHome} | Should -Throw "IIBHome [$IIBHome] does not exist"
            }

            It "Throws exception when IIBHome is invalid" {
                $IIBHome = 'A directory that exists'
                $IIBCmd = Join-Path -Path $IIBHome -ChildPath 'iib.cmd'
                Mock Test-Path { $true } -ParameterFilter {$Path -eq $IIBHome}
                Mock Test-Path { $false } -ParameterFilter {$Path -eq $IIBCmd}

                {Set-IIBHome -IIBHome $IIBHome} | Should -Throw "IIBHome is invalid. Script [$IIBCmd] does not exist"
            }

            It "Sets valid IIBHome" {
                $IIBHome = 'TestDrive:\iib\10.0.0.x'
                $IIBCmd = Join-Path -Path $IIBHome -ChildPath 'iib.cmd'
                Mock Test-Path { $true } -ParameterFilter {$Path -eq $IIBHome}
                Mock Test-Path { $true } -ParameterFilter {$Path -eq $IIBCmd}

                New-Item -Path "TestDrive:\PSIIB" -ItemType Directory
                $ModuleConfigPath = "TestDrive:\PSIIB\PSIIB.json"
                Mock Get-ModuleConfigPath { $ModuleConfigPath }

                $ModuleConfigPath | Should -Not -Exist
                Set-IIBHome -IIBHome $IIBHome
                $ModuleConfigPath | Should -Exist

                $Content = '"IIBHome":  "{0}"' -f $IIBHome.Replace('\', '\\')
                $ModuleConfigPath | Should -FileContentMatch ([regex]::Escape($Content))
            }
        }

        Context "IIBHome getting" {
            It "Throws exception when module is not configured" {
                $ModuleConfigPath = "TestDrive:\PSIIB\PSIIB.json"
                Mock Get-ModuleConfigPath { $ModuleConfigPath }

                {Get-IIBHome} | Should -Throw "Module not configured. Please use Set-IIBHome to configure"
            }

            It "Throws exception when IIBHome is not set or blank" {
                $ModuleConfigPath = "TestDrive:\PSIIB\PSIIB.json"
                Mock Get-ModuleConfigPath { $ModuleConfigPath }
                Mock Test-Path { $true } -ParameterFilter { $Path -eq $ModuleConfigPath}

                Mock Get-ModuleConfig { [PSCustomObject]@{} }

                {Get-IIBHome} | Should -Throw "IIBHome not set or is blank"
            }

            It "Throws exception when IIBHome does not exist" {
                $ModuleConfigPath = "TestDrive:\PSIIB\PSIIB.json"
                Mock Get-ModuleConfigPath { $ModuleConfigPath }
                Mock Test-Path { $true } -ParameterFilter { $Path -eq $ModuleConfigPath}

                $IIBHome = 'A directory that does not exist'
                Mock Get-ModuleConfig { [PSCustomObject]@{IIBHome = $IIBHome} }

                {Get-IIBHome} | Should -Throw "IIBHome [$IIBHome] does not exist"
            }

            It "Throws exception when IIBHome is invalid" {
                $ModuleConfigPath = "TestDrive:\PSIIB\PSIIB.json"
                Mock Get-ModuleConfigPath { $ModuleConfigPath }
                Mock Test-Path { $true } -ParameterFilter { $Path -eq $ModuleConfigPath}

                $IIBHome = 'A directory that exists'
                $IIBCmd = Join-Path -Path $IIBHome -ChildPath 'iib.cmd'
                Mock Get-ModuleConfig { [PSCustomObject]@{IIBHome = $IIBHome} }
                Mock Test-Path { $true } -ParameterFilter {$Path -eq $IIBHome}
                Mock Test-Path { $false } -ParameterFilter {$Path -eq $IIBCmd}

                {Get-IIBHome} | Should -Throw "IIBHome is invalid. Script [$IIBCmd] does not exist"
            }

            It "Gets valid IIBHome" {
                $ModuleConfigPath = "TestDrive:\PSIIB\PSIIB.json"
                Mock Get-ModuleConfigPath { $ModuleConfigPath }
                Mock Test-Path { $true } -ParameterFilter { $Path -eq $ModuleConfigPath}

                $IIBHome = 'A directory that exists'
                $IIBCmd = Join-Path -Path $IIBHome -ChildPath 'iib.cmd'
                Mock Get-ModuleConfig { [PSCustomObject]@{IIBHome = $IIBHome} }
                Mock Test-Path { $true } -ParameterFilter {$Path -eq $IIBHome}
                Mock Test-Path { $true } -ParameterFilter {$Path -eq $IIBCmd}

                Get-IIBHome | Should -BeExactly $IIBHome
            }
        }
    }
}