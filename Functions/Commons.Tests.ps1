InModuleScope PSIIB {
    Describe "IIB Home configuration" -Tags ('Commons', 'IIBHome') {
        $ModuleConfigPath = "TestDrive:\PSIIB.json"
        Mock Get-ModuleConfigPath { $ModuleConfigPath }

        $IIBHome = "TestDrive:\iib\10.0.0.x"
        $IIBCmd  = "$IIBHome\iib.cmd"

        Context "IIBHome setting" {
            It "Throws exception when IIBHome does not exist" {
                Mock Test-Path { $false } -ParameterFilter {$Path -eq $IIBHome}

                {Set-IIBHome -IIBHome $IIBHome} | Should -Throw "IIBHome [$IIBHome] does not exist"
            }

            It "Throws exception when IIBHome is invalid" {
                Mock Test-Path { $true  } -ParameterFilter {$Path -eq $IIBHome}
                Mock Test-Path { $false } -ParameterFilter {$Path -eq $IIBCmd}

                {Set-IIBHome -IIBHome $IIBHome} | Should -Throw "IIBHome is invalid. Script [$IIBCmd] does not exist"
            }

            It "Sets valid IIBHome - create new one" {
                Mock Test-Path { $true } -ParameterFilter {$Path -eq $IIBHome}
                Mock Test-Path { $true } -ParameterFilter {$Path -eq $IIBCmd}

                $ModuleConfigPath | Should -Not -Exist

                Set-IIBHome -IIBHome $IIBHome

                $ModuleConfigPath | Should -Exist

                $Content = '"IIBHome":  "{0}"' -f $IIBHome.Replace('\', '\\')
                $ModuleConfigPath | Should -FileContentMatch ([regex]::Escape($Content))
            }

            It "Sets valid IIBHome - override existing one" {
                Mock Test-Path { $true } -ParameterFilter {$Path -eq $IIBHome}
                Mock Test-Path { $true } -ParameterFilter {$Path -eq $IIBCmd}

                "{'IIBHome':  'InvalidPath'}" | Set-Content $ModuleConfigPath
                (Get-Content -Path $ModuleConfigPath -Raw | ConvertFrom-Json).IIBHome | Should -Be "InvalidPath"

                Set-IIBHome -IIBHome $IIBHome
                (Get-Content -Path $ModuleConfigPath -Raw | ConvertFrom-Json).IIBHome | Should -Be $IIBHome
            }
        }

        Context "IIBHome getting" {
            It "Throws exception when module is not configured" {    
                Mock Test-Path { $false } -ParameterFilter { $Path -eq $ModuleConfigPath}

                {Get-IIBHome} | Should -Throw "Module not configured"
            }

            It "Throws exception when IIBHome is not set or blank" {
                Mock Test-Path { $true } -ParameterFilter { $Path -eq $ModuleConfigPath}

                Mock Get-ModuleConfig { @{} }
                {Get-IIBHome} | Should -Throw "IIBHome not set or is blank"

                Mock Get-ModuleConfig { @{IIBHome=' '} }
                {Get-IIBHome} | Should -Throw "IIBHome not set or is blank"
            }

            It "Throws exception when IIBHome does not exist" {
                Mock Test-Path { $true } -ParameterFilter { $Path -eq $ModuleConfigPath}
                Mock Get-ModuleConfig { @{IIBHome = $IIBHome} }
                Mock Test-Path { $false } -ParameterFilter {$Path -eq $IIBHome}

                {Get-IIBHome} | Should -Throw "IIBHome [$IIBHome] does not exist"
            }

            It "Throws exception when IIBHome is invalid" {
                Mock Test-Path { $true } -ParameterFilter { $Path -eq $ModuleConfigPath}
                Mock Get-ModuleConfig { @{IIBHome = $IIBHome} }
                Mock Test-Path { $true  } -ParameterFilter {$Path -eq $IIBHome}
                Mock Test-Path { $false } -ParameterFilter {$Path -eq $IIBCmd}

                {Get-IIBHome} | Should -Throw "IIBHome is invalid. Script [$IIBCmd] does not exist"
            }

            It "Gets valid IIBHome" {
                Mock Test-Path { $true } -ParameterFilter { $Path -eq $ModuleConfigPath}
                Mock Get-ModuleConfig { @{IIBHome = $IIBHome} }
                Mock Test-Path { $true } -ParameterFilter {$Path -eq $IIBHome}
                Mock Test-Path { $true } -ParameterFilter {$Path -eq $IIBCmd}

                Get-IIBHome | Should -BeExactly $IIBHome
            }
        }
    }

    Describe "IIB Root configuration" -Tags ('Commons', 'IIBRoot') {
        $ModuleConfigPath = "TestDrive:\PSIIB.json"
        Mock Get-ModuleConfigPath { $ModuleConfigPath }

        $RootName1 = 'Root1'
        $RootPath1 = 'TestDrive:\iib\projects1'

        Context "IIBRoot setting" {
            It "Throws exception when IIBRoot does not exist" {
                Mock Test-Path { $false } -ParameterFilter {$Path -eq $RootPath1}

                {Set-IIBRoot -RootName $RootName1 -RootPath $RootPath1} | Should -Throw "Root path [$RootPath1] does not exist"
            }

            It "Sets valid IIBRoot - create new one" {
                Mock Test-Path { $true } -ParameterFilter {$Path -eq $RootPath1}

                $ModuleConfigPath | Should -Not -Exist

                Set-IIBRoot -RootName $RootName1 -RootPath $RootPath1
                $ModuleConfigPath | Should -Exist

                $Content = '"{0}":  "{1}"' -f $RootName1, $RootPath1.Replace('\', '\\')
                $ModuleConfigPath | Should -FileContentMatch ([regex]::Escape($Content))
            }

            It "Sets valid IIBRoot - override existing one" {
                Mock Test-Path { $true } -ParameterFilter {$Path -eq $RootPath1}

                "{'IIBRoot': {'$RootName1': 'InvalidPath'}}"  | Set-Content $ModuleConfigPath
                (Get-Content -Path $ModuleConfigPath -Raw | ConvertFrom-Json).IIBRoot.$RootName1 | Should -Be "InvalidPath"

                Set-IIBRoot -RootName $RootName1 -RootPath $RootPath1
                (Get-Content -Path $ModuleConfigPath -Raw | ConvertFrom-Json).IIBRoot.$RootName1 | Should -Be $RootPath1
            }
        }

        Context "IIBRoot getting" {
            It "Throws exception when module is not configured" {
                Mock Test-Path { $false } -ParameterFilter { $Path -eq $ModuleConfigPath}

                {Get-IIBRoot} | Should -Throw "Module not configured"
            }
            
            It "Gets the root path for the specified root name" {
                Mock Test-Path { $true } -ParameterFilter { $Path -eq $ModuleConfigPath}
                Mock Test-Path { $true } -ParameterFilter { $Path -eq $RootPath1}
                Mock Get-ModuleConfig {
                    @{
                        "IIBRoot" = @{$RootName1 = $RootPath1; "Root2" = "TestDrive:\iib\projects2"}
                    }
                }

                Get-IIBRoot -RootName $RootName1 | Should -Be $RootPath1
            }

            It "Gets the root path without name specified when there is only one IIB root" {
                Mock Test-Path { $true } -ParameterFilter { $Path -eq $ModuleConfigPath}
                Mock Test-Path { $true } -ParameterFilter { $Path -eq $RootPath1}
                Mock Get-ModuleConfig {
                    @{
                        "IIBRoot" = @{$RootName1 = $RootPath1}
                    } 
                }

                Get-IIBRoot | Should -Be $RootPath1
            }

            It "Throws exception when gets the root path without name specified and there are multiple IIB roots" {
                Mock Test-Path { $true } -ParameterFilter { $Path -eq $ModuleConfigPath}
                Mock Get-ModuleConfig {
                    @{
                        "IIBRoot" = @{$RootName1 = $RootPath1; "Root2" = "TestDrive:\iib\projects2"}
                    }
                }

                {Get-IIBRoot} | Should -Throw "Multiple paths exist, root name required"
            }

            It "Throws exception when the root path is not set or blank" {
                Mock Test-Path { $true } -ParameterFilter { $Path -eq $ModuleConfigPath}
                
                Mock Get-ModuleConfig { @{} }
                {Get-IIBRoot -RootName $RootName1} | Should -Throw "IIBRoot not set or is blank"

                Mock Get-ModuleConfig {@{"IIBRoot" = @{$RootName = " "}}}
                {Get-IIBRoot -RootName $RootName1} | Should -Throw "IIBRoot not set or is blank"
            }

            It "Gets all the root name and paths" {
                Mock Test-Path { $true } -ParameterFilter { $Path -eq $ModuleConfigPath}
                Mock Get-ModuleConfig {
                    @{
                        "IIBRoot" = @{$RootName1 = $RootPath1; "Root2" = "TestDrive:\iib\projects2"}
                    }
                }
                

                $ProjectRoots = Get-IIBRoot -All
                $ProjectRoots | Should -HaveCount 2
                $ProjectRoots[0].RootName | Should -Be $RootName1
                $ProjectRoots[0].RootPath | Should -Be $RootPath1
                $ProjectRoots[1].RootName | Should -Be 'Root2'
                $ProjectRoots[1].RootPath | Should -Be 'TestDrive:\iib\projects2'
            }
        }
    }
}