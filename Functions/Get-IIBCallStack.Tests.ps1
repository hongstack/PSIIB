InModuleScope PSIIB {
    Describe "script scope variables initialization" -Tags ('CallStack', 'Init') {
        Context "APP_ROOT initialization" {
            $TestRootName = 'IIB_Projects'
            Mock Get-AppList {}

            It "Initializes APP_ROOT" {
                $AppRoot = (New-Item -Path "TestDrive:\iib\projects" -ItemType Directory).FullName
                Mock Get-IIBRoot { $AppRoot } -ParameterFilter { $RootName -eq $TestRootName }

                Get-IIBCallStack -RootName $TestRootName -Resource 'Any flow or function name'

                $Script:APP_ROOT | Should -Be $AppRoot

                Assert-MockCalled Get-AppList 1 -Scope It
                $Script:APP_LIST | Should -Be $null
            }

            It "Throws exception when IIB root is not defined" {
                {Get-IIBCallStack -RootName $TestRootName -Resource 'Any flow or function name'} | Should -Throw "No path is defined for $TestRootName"
                Assert-MockCalled Get-AppList 0 -Scope It
            }

            It "Throws exception when IIB root does not exist" {
                $AppRoot = 'A directory that does not exist'
                Mock Get-IIBRoot { $AppRoot } -ParameterFilter {$RootName -eq $TestRootName}

                {Get-IIBCallStack -RootName $TestRootName -Resource 'Any flow or function name'} | Should -Throw "Path does not exist: $AppRoot"
                Assert-MockCalled Get-AppList 0 -Scope It
            }
        }

        Context "APP_LIST initialization" {
            It "Initializes APP_LIST" {
                $AppRoot = (New-Item -Path "TestDrive:\iib\projects" -ItemType Directory).FullName
                Mock Get-AppRoot { $AppRoot }
                Mock Get-LibRefs {}
                Mock Get-FlowCallStack {}
                Mock Get-RoutineCallStack {}

                New-Item -Path "$AppRoot\APP_X\rba\app\x" -ItemType Directory
                '<Any Content/>' | Set-Content -Path "$AppRoot\APP_X\.project"
                '<Any Content/>' | Set-Content -Path "$AppRoot\APP_X\rba\app\x\MF_APP.msgflow"

                Get-IIBCallStack -RootName 'Any Name' -Resource 'Any flow or function name'

                $Script:APP_LIST | Should -HaveCount 1
                $Script:APP_LIST.Name | Should -Contain 'APP_X'
            }
        }

        Context "LIB_REFS initialization" {
            It "Initializes LIB_REFS" {
                $AppRoot = (New-Item -Path "TestDrive:\iib\projects" -ItemType Directory).FullName
                Mock Get-AppRoot { $AppRoot }
                Mock Get-FlowCallStack {}
                Mock Get-RoutineCallStack {}

                New-Item -Path "$AppRoot\APP_X\rba\app\x" -ItemType Directory
                '<projectDescription>',
                '  <name>APP_X</name>',
                '  <projects>',
                '    <project>APPLIB_X</project>',
                '	</projects>',
                '</projectDescription>' | Set-Content -Path "$AppRoot\APP_X\.project"
                '<EPackage />' | Set-Content -Path "$AppRoot\APP_X\rba\app\x\MF_APP.msgflow"

                Get-IIBCallStack -RootName 'Any Name' -Resource 'Any flow or function name'

                $Script:LIB_REFS.Keys | Should -HaveCount 1
                $Script:LIB_REFS.Keys | Should -Contain 'APPLIB_X'

                $Script:LIB_REFS.Values | Should -HaveCount 1
                $Script:LIB_REFS.Values | Select -First 1 | Should -Be 'APP_X'
            }
        }

        Context "SEARCH_SCOPE determination" {
            $AppRoot = 'C:\fake\dir'

            It "Returns apps/libs to search for the specified app" {
                Mock Get-AppRoot {$AppRoot}
                Mock Get-AppList {}
                Mock Get-LibRefs {
                    @{
                        'APPLIB_X' = $($V=[HashSet[String]]::new(); [Void]$V.Add('APP_X'); $V)
                        'APPLIB_Y' = $($V=[HashSet[String]]::new(); [Void]$V.Add('APP_X'); [Void]$V.Add('APP_Y'); $V)
                    }
                }

                Get-IIBCallStack -RootName 'Any Name' -Resource 'Any flow or function name'

                Get-SearchScope APPLIB_X | Should -HaveCount 2
                Get-SearchScope APPLIB_X | Should -Be @("$AppRoot\APPLIB_X", "$AppRoot\APP_X")

                Get-SearchScope APPLIB_Y | Should -HaveCount 3
                Get-SearchScope APPLIB_Y | Should -Be @("$AppRoot\APPLIB_Y", "$AppRoot\APP_X", "$AppRoot\APP_Y")

                Get-SearchScope APPLIB_Z | Should -HaveCount 1
                Get-SearchScope APPLIB_Z | Should -Be @("$AppRoot\APPLIB_Z")
            }
        }
    }

    Describe "call match class" -Tags ('CallStack', 'CallMatch') {
        $AppRoot = 'C:\fake\dir'

        Context "CallMatch class" {
            $CallMatch = [CallMatch]::new(@{
                AppRoot  = "$AppRoot"
                FullPath = "$AppRoot\App1\path\file.ext"
            });

            It "Extracts valid relative path" {
                $CallMatch.AppPath | Should -Be 'App1\path\file.ext'
            }

            It "Extracts valid app name" {
                $CallMatch.AppName | Should -Be 'App1'
            }

            It "Returns default depth of zero" {
                $CallMatch.Depth | Should -Be 0
            }
        }

        Context "FlowCallMatch class" {
            $FlowCallMatch = [FlowCallMatch]::new(@{
                AppRoot  = "$AppRoot"
                FullPath = "$AppRoot\App1\path\file.msgflow"
                Depth   = 3
            })

            It "Detects the flow type" {
                $FlowCallMatch.IsMessageFlow() | Should -BeTrue
            }

            It "Returns the given depth" {
                $FlowCallMatch.Depth | Should -Be 3
            }

            It "Returns flow call pattern in message flow" {
                $FlowCallMatch.GetFlowCallPatternInFlow() | Should -Be 'xmi:type="path_file.msgflow'
            }
        }

        Context "RoutineCallMatch class" {
            It "Returns correct match info" {
                $RoutineCallMatch = [RoutineCallMatch]::new(@{
                    AppRoot  = "$AppRoot"
                    FullPath = "$AppRoot\APP_X\rba\app\x\APP_X.esql"
                    Routine = 'MyFunc'
                    Line = 'CREATE FUNCTION MyFunc (IN param CHARACTER)'
                    LineNumber = '100'
                })

                $RoutineCallMatch.Routine    | Should -Be 'MyFunc'
                $RoutineCallMatch.Line       | Should -BeLike '*MyFunc*'
                $RoutineCallMatch.LineNumber | Should -Be 100
                $RoutineCallMatch.IsMainRoutine() | Should -Be $False
            }

            It "Returns routine call pattern in message flow" {
                $RoutineCallMatch = [RoutineCallMatch]::new(@{
                    AppRoot  = "$AppRoot"
                    FullPath = "$AppRoot\APP_X\rba\app\x\APP_X.esql"
                    Routine = 'MyModule.Main'
                    Line = 'CREATE FUNCTION Main () RETURNS BOOLEAN'
                    LineNumber = '100'
                })

                $RoutineCallMatch.IsMainRoutine() | Should -Be $True
                $RoutineCallMatch.GetRoutineCallPatternInFlow() | Should -Be 'esql://routine/rba.app.x#MyModule.Main'
            }
        }
    }

    Describe "message flow call stack" -Tags ('CallStack', 'FlowCallStack'){
        It "Should print flow call stack" {
            $AppRoot = (New-Item -Path "TestDrive:\iib\projects" -ItemType Directory).FullName
            Mock Get-AppRoot { $AppRoot }

            New-Item -Path "$AppRoot\SHLIB_X\rba\lib\x" -ItemType Directory
            '<projectDescription>',
            '  <name>SHLIB_X</name>',
            '  <projects/>',
            '</projectDescription>' | Set-Content -Path "$AppRoot\SHLIB_X\.project"
            '<EPackage />' | Set-Content -Path "$AppRoot\SHLIB_X\rba\lib\x\SF_Common.subflow"

            New-Item -Path "$AppRoot\APPLIB_X\rba\applib\x" -ItemType Directory
            '<projectDescription>',
            '  <name>APPLIB_X</name>',
            '  <projects>',
            '    <project>SHLIB_X</project>',
            '	</projects>',
            '</projectDescription>' | Set-Content -Path "$AppRoot\APPLIB_X\.project"
            '<composition>',
            '  <nodes xmi:type="rba_lib_x_SF_Common.subflow:FCMComposite_1">',
            '    <translation any_attributes/>',
            '  </nodes>',
            '</composition>' | Set-Content -Path "$AppRoot\APPLIB_X\rba\applib\x\SF_APPLib.subflow"

            New-Item -Path "$AppRoot\APP_X\rba\app\x" -ItemType Directory
            '<projectDescription>',
            '  <name>APP_X</name>',
            '  <projects>',
            '    <project>APPLIB_X</project>',
            '  </projects>',
            '</projectDescription>' | Set-Content -Path "$AppRoot\APP_X\.project"
            '<composition>',
            '  <nodes xmi:type="rba_applib_x_SF_APPLib.subflow:FCMComposite_1">',
            '    <translation any_attributes/>',
            '  </nodes>',
            '</composition>' | Set-Content -Path "$AppRoot\APP_X\rba\app\x\MF_APP.msgflow"

            $Output = (Get-IIBCallStack -RootName 'Any Name' -Resource 'SF_Common.subflow' 6>&1)

            $Output | Should -HaveCount 6
            -Join $Output[0,1] | Should -Be 'SHLIB_X\rba\lib\x\SF_Common.subflow'
            -Join $Output[2,3] | Should -Be '    APPLIB_X\rba\applib\x\SF_APPLib.subflow'
            -Join $Output[4,5] | Should -Be '        APP_X\rba\app\x\MF_APP.msgflow'
        }
    }

    Describe "routine call stack" -Tags ('CallStack', 'EsqlCallStack') {
        It "Should print routine call stack" {
            $AppRoot = (New-Item -Path "TestDrive:\iib\projects" -ItemType Directory).FullName
            Mock Get-AppRoot { $AppRoot }

            New-Item -Path "$AppRoot\SHLIB_X\rba\lib\x" -ItemType Directory
            '<projectDescription>',
            '  <name>SHLIB_X</name>',
            '  <projects/>',
            '</projectDescription>' | Set-Content -Path "$AppRoot\SHLIB_X\.project"
            'BROKER SCHEMA rba.lib.x',
            'DECLARE ... ;',
            'CREATE FUNCTION Shared_Func(IN p CHARACTER) RETURNS CHARACTER',
            'BEGIN ... END;' | Set-Content -Path "$AppRoot\SHLIB_X\rba\lib\x\SharedLibX.esql"

            New-Item -Path "$AppRoot\APPLIB_X\rba\applib\x" -ItemType Directory
            '<projectDescription>',
            '  <name>APPLIB_X</name>',
            '  <projects>',
            '    <project>SHLIB_X</project>',
            '	</projects>',
            '</projectDescription>' | Set-Content -Path "$AppRoot\APPLIB_X\.project"
            'BROKER SCHEMA rba.applib.x',
            'DECLARE ... ;',
            'CREATE PROCEDURE Common_Utils() BEGIN',
            '  CALL Shared_Func(arg);',
            'END;' | Set-Content -Path "$AppRoot\APPLIB_X\rba\applib\x\APPLibX.esql"

            New-Item -Path "$AppRoot\APPLIB_Y\rba\applib\y" -ItemType Directory
            '<projectDescription>',
            '  <name>APPLIB_Y</name>',
            '  <projects>',
            '    <project>SHLIB_X</project>',
            '	</projects>',
            '</projectDescription>' | Set-Content -Path "$AppRoot\APPLIB_Y\.project"
            'BROKER SCHEMA rba.applib.y',
            'DECLARE ... ;',
            'CREATE PROCEDURE Func_Utils() BEGIN',
            '  DECLARE out Character;',
            '  SET out = Shared_Func(arg).toUpperCase();',
            'END;' | Set-Content -Path "$AppRoot\APPLIB_Y\rba\applib\y\APPLibY.esql"

            New-Item -Path "$AppRoot\APP_X\rba\app\x" -ItemType Directory
            '<projectDescription>',
            '  <name>APP_X</name>',
            '  <projects>',
            '    <project>APPLIB_X</project>',
            '	</projects>',
            '</projectDescription>' | Set-Content -Path "$AppRoot\APP_X\.project"
            'BROKER SCHEMA rba.app.x',
            'DECLARE ... ;',
            'CREATE DATABASE MODULE Test',
            'CREATE FUNCTION Main() RETURNS BOOLEAN BEGIN',
            '  CALL Common_Utils();',
            '  RETURN TRUE;',
            'END;',
            'END MODULE;' | Set-Content -Path "$AppRoot\APP_X\rba\app\x\APP_X.esql"

            '<composition>',
            '  <nodes statement="esql://routine/rba.app.x#Test.Main">',
            '    <translation any_attributes/>',
            '  </nodes>',
            '</composition>' | Set-Content -Path "$AppRoot\APP_X\rba\app\x\MF_APP.msgflow"

            $Output = (Get-IIBCallStack -RootName 'Any Name' -Resource 'Shared_Func' 6>&1)
            
            $Output | Should -HaveCount 18
            (-Join $Output[0..3])   | Should -Be 'SHLIB_X\rba\lib\x\SharedLibX.esql:3:CREATE FUNCTION Shared_Func(IN p CHARACTER) RETURNS CHARACTER'
            (-Join $Output[4..7])   | Should -Be '    APPLIB_Y\rba\applib\y\APPLibY.esql:5:SET out = Shared_Func(arg).toUpperCase();'
            (-Join $Output[8..11])  | Should -Be '    APPLIB_X\rba\applib\x\APPLibX.esql:4:CALL Shared_Func(arg);'
            (-Join $Output[12..15]) | Should -Be '        APP_X\rba\app\x\APP_X.esql:5:CALL Common_Utils();'
            (-Join $Output[16..18]) | Should -Be '            APP_X\rba\app\x\MF_APP.msgflow'
        }
    }

    Describe "getting IIBRoot" -Tags ('CallStack', 'Get-IIBRoot') {
        It "Returns the value for the specified root name" {
            $ConfigPath = Join-Path $TestDrive 'PSIIB.json'
            '{"IIBRoot": {"App1": "C:\\Dev\\App1", "App2": "C:\\Dev\\App2"}}' | Set-Content -Path $ConfigPath

            Mock Get-ModuleConfigPath { $ConfigPath }

            Get-IIBRoot -RootName 'App1' | Should -Be 'C:\Dev\App1'
            Get-IIBRoot -RootName 'App2' | Should -Be 'C:\Dev\App2'
        }

        It "Returns the only value when root name not specified" {
            $ConfigPath = Join-Path $TestDrive 'PSIIB.json'
            '{"IIBRoot": {"App1": "C:\\Dev\\App1"}}' | Set-Content -Path $ConfigPath

            Mock Get-ModuleConfigPath { $ConfigPath }

            Get-IIBRoot | Should -Be 'C:\Dev\App1'
        }

        It "Returns all the root name and paths" {
            $ConfigPath = Join-Path $TestDrive 'PSIIB.json'
            '{"IIBRoot": {"App1": "C:\\Dev\\App1", "App2": "C:\\Dev\\App2"}}' | Set-Content -Path $ConfigPath

            Mock Get-ModuleConfigPath { $ConfigPath }

            $AllPaths = Get-IIBRoot -All
            $AllPaths | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | Should -Be @('App1', 'App2')
            $AllPaths.App1 | Should -Be 'C:\Dev\App1'
            $AllPaths.App2 | Should -Be 'C:\Dev\App2'
        }

        It "Returns null when path does not exist" {
            Mock Get-ModuleConfigPath { 'A directory that does not exist' } -ModuleName PSIIB

            Get-IIBRoot -RootName 'Any Name' | Should -Be $null
        }

        It "Returns null when value not set" {
            $ConfigPath = Join-Path $TestDrive 'PSIIB.json'
            Mock Get-ModuleConfigPath { $ConfigPath }

            '{}' | Set-Content -Path $ConfigPath
            Get-IIBRoot | Should -Be $null

            '{"IIBRoot": {}}' | Set-Content -Path $ConfigPath
            Get-IIBRoot | Should -Be $null

            '{"IIBRoot": {"App1": "C:\\Dev\\App1"}}' | Set-Content -Path $ConfigPath
            Get-IIBRoot -RootName 'App2' | Should -Be $null
        }

        It "Throws exception when multiple paths exist and root name not specfied" {
            $ConfigPath = Join-Path $TestDrive 'PSIIB.json'
            '{"IIBRoot": {"App1": "C:\\Dev\\App1", "App2": "C:\\Dev\\App2"}}' | Set-Content -Path $ConfigPath

            Mock Get-ModuleConfigPath { $ConfigPath }

            {Get-IIBRoot} | Should -Throw "Multiple paths exist, root name required"
        }
    }

    Describe "setting IIBRoot" -Tags ('CallStack', 'Set-IIBRoot') {
        It "Sets the root directory for the specified root name" {
            $ConfigPath = Join-Path $TestDrive 'PSIIB.json'
            Mock Get-ModuleConfigPath { $ConfigPath }

            Set-IIBRoot -RootName App1 -RootPath 'C:\Dev\App1'
            Get-IIBRoot -RootName App1 | Should -Be 'C:\Dev\App1'
            Get-IIBRoot | Should -Be 'C:\Dev\App1'
        }
    }
}
