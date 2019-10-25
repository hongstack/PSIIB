InModuleScope PSIIB {
    Describe "script scope variables initialization" -Tags ('CallStack', 'Init') {
        $TestRootName = 'IIB_Projects'
        $TestRootPath = "$TestDrive\iib\projects"
        Mock Get-IIBRoot { $TestRootPath } -ParameterFilter { $RootName -eq $TestRootName }
        
        Context "APP_ROOT initialization" {
            It "Initializes APP_ROOT" {
                Mock Get-AppList {} # Prevent further execution

                Get-IIBCallStack -RootName $TestRootName -Resource 'Any flow or function name'

                $Script:APP_ROOT | Should -Be $TestRootPath
                Assert-MockCalled Get-AppList -Times 1 -Scope It
                $Script:APP_LIST | Should -Be $null
            }
        }

        Context "APP_LIST initialization" {
            It "Initializes APP_LIST" {
                Mock Get-LibRefs {}
                Mock Get-FlowCallStack {}
                Mock Get-RoutineCallStack {}

                New-Item -Path "$TestRootPath\APP_X\rba\app\x" -ItemType Directory
                '<Any Content/>' | Set-Content -Path "$TestRootPath\APP_X\.project"
                '<Any Content/>' | Set-Content -Path "$TestRootPath\APP_X\rba\app\x\MF_APP.msgflow"

                Get-IIBCallStack -RootName $TestRootName -Resource 'Any flow or function name'

                $Script:APP_LIST | Should -HaveCount 1
                $Script:APP_LIST | Should -Be @('APP_X')
            }
        }

        Context "LIB_REFS initialization" {
            It "Initializes LIB_REFS" {
                Mock Get-FlowCallStack {}
                Mock Get-RoutineCallStack {}

                New-Item -Path "$TestRootPath\APP_X\rba\app\x" -ItemType Directory
                '<projectDescription>',
                '  <name>APP_X</name>',
                '  <projects>',
                '    <project>APPLIB_X</project>',
                '   </projects>',
                '</projectDescription>' | Set-Content -Path "$TestRootPath\APP_X\.project"
                '<EPackage />' | Set-Content -Path "$TestRootPath\APP_X\rba\app\x\MF_APP.msgflow"
                New-Item -Path "$TestRootPath\APPLIB_X\rba\applib\x" -ItemType Directory
                '<projectDescription>',
                '  <name>APPLIB_X</name>',
                '  <projects>',
                '    <project>SHLIB_X</project>',
                '   </projects>',
                '</projectDescription>' | Set-Content -Path "$TestRootPath\APPLIB_X\.project"
                '<EPackage />' | Set-Content -Path "$TestRootPath\APPLIB_X\rba\applib\x\SF_APPLib.subflow"

                Get-IIBCallStack -RootName $TestRootName -Resource 'Any flow or function name'

                $Script:LIB_REFS.Keys | Should -HaveCount 2
                $Script:LIB_REFS.Keys | Select -First 2 | Should -Be @('APPLIB_X', 'SHLIB_X')

                $Script:LIB_REFS['APPLIB_X'] | Should -HaveCount 1
                $Script:LIB_REFS['APPLIB_X'] | Select -First 1 | Should -Be 'APP_X'

                $Script:LIB_REFS['SHLIB_X'] | Should -HaveCount 2
                $Script:LIB_REFS['SHLIB_X'] | Select -First 2 | Should -Be @('APPLIB_X', 'APP_X')
            }
        }

        Context "SEARCH_SCOPE determination" {
            It "Gets apps/libs to search for the specified app" {
                Mock Get-AppList {}
                Mock Get-LibRefs {
                    @{
                        'APPLIB_X' = $($V=[HashSet[String]]::new(); [Void]$V.Add('APP_X'); $V)
                        'APPLIB_Y' = $($V=[HashSet[String]]::new(); [Void]$V.Add('APP_X'); [Void]$V.Add('APP_Y'); $V)
                    }
                }

                Get-IIBCallStack -RootName $TestRootName -Resource 'Any flow or function name'

                Get-SearchScope APPLIB_X | Should -HaveCount 2
                Get-SearchScope APPLIB_X | Should -Be @("$TestRootPath\APPLIB_X", "$TestRootPath\APP_X")

                Get-SearchScope APPLIB_Y | Should -HaveCount 3
                Get-SearchScope APPLIB_Y | Should -Be @("$TestRootPath\APPLIB_Y", "$TestRootPath\APP_X", "$TestRootPath\APP_Y")

                Get-SearchScope APPLIB_Z | Should -HaveCount 1
                Get-SearchScope APPLIB_Z | Should -Be @("$TestRootPath\APPLIB_Z")
            }
        }
    }

    Describe "message flow call stack" -Tags ('CallStack', 'FlowCallStack'){
        It "Should print flow call stack" {
            $TestRootName = 'IIB_Projects'
            $TestRootPath = "$TestDrive\iib\projects"
            Mock Get-IIBRoot { $TestRootPath } -ParameterFilter { $RootName -eq $TestRootName }

            New-Item -Path "$TestRootPath\SHLIB_X\rba\lib\x" -ItemType Directory
            '<projectDescription>',
            '  <name>SHLIB_X</name>',
            '  <projects/>',
            '</projectDescription>' | Set-Content -Path "$TestRootPath\SHLIB_X\.project"
            '<EPackage />' | Set-Content -Path "$TestRootPath\SHLIB_X\rba\lib\x\SF_Common.subflow"

            New-Item -Path "$TestRootPath\APPLIB_X\rba\applib\x" -ItemType Directory
            '<projectDescription>',
            '  <name>APPLIB_X</name>',
            '  <projects>',
            '    <project>SHLIB_X</project>',
            '   </projects>',
            '</projectDescription>' | Set-Content -Path "$TestRootPath\APPLIB_X\.project"
            '<composition>',
            '  <nodes xmi:type="rba_lib_x_SF_Common.subflow:FCMComposite_1">',
            '    <translation any_attributes/>',
            '  </nodes>',
            '</composition>' | Set-Content -Path "$TestRootPath\APPLIB_X\rba\applib\x\SF_APPLib.subflow"

            New-Item -Path "$TestRootPath\APP_X\rba\app\x" -ItemType Directory
            '<projectDescription>',
            '  <name>APP_X</name>',
            '  <projects>',
            '    <project>APPLIB_X</project>',
            '  </projects>',
            '</projectDescription>' | Set-Content -Path "$TestRootPath\APP_X\.project"
            '<composition>',
            '  <nodes xmi:type="rba_applib_x_SF_APPLib.subflow:FCMComposite_1">',
            '    <translation any_attributes/>',
            '  </nodes>',
            '</composition>' | Set-Content -Path "$TestRootPath\APP_X\rba\app\x\MF_APP.msgflow"

            $Output = (Get-IIBCallStack -RootName $TestRootName -Resource 'SF_Common.subflow' 6>&1)

            $Output | Should -HaveCount 6
            -Join $Output[0,1] | Should -Be 'SHLIB_X\rba\lib\x\SF_Common.subflow'
            -Join $Output[2,3] | Should -Be '    APPLIB_X\rba\applib\x\SF_APPLib.subflow'
            -Join $Output[4,5] | Should -Be '        APP_X\rba\app\x\MF_APP.msgflow'
        }
    }

    Describe "routine call stack" -Tags ('CallStack', 'EsqlCallStack') {
        It "Should print routine call stack" {
            $TestRootName = 'IIB_Projects'
            $TestRootPath = "$TestDrive\iib\projects"
            Mock Get-IIBRoot { $TestRootPath } -ParameterFilter { $RootName -eq $TestRootName }

            New-Item -Path "$TestRootPath\SHLIB_X\rba\lib\x" -ItemType Directory
            '<projectDescription>',
            '  <name>SHLIB_X</name>',
            '  <projects/>',
            '</projectDescription>' | Set-Content -Path "$TestRootPath\SHLIB_X\.project"
            'BROKER SCHEMA rba.lib.x',
            'DECLARE ... ;',
            'CREATE FUNCTION Shared_Func(IN p CHARACTER) RETURNS CHARACTER',
            'BEGIN ... END;' | Set-Content -Path "$TestRootPath\SHLIB_X\rba\lib\x\SharedLibX.esql"

            New-Item -Path "$TestRootPath\APPLIB_X\rba\applib\x" -ItemType Directory
            '<projectDescription>',
            '  <name>APPLIB_X</name>',
            '  <projects>',
            '    <project>SHLIB_X</project>',
            '   </projects>',
            '</projectDescription>' | Set-Content -Path "$TestRootPath\APPLIB_X\.project"
            'BROKER SCHEMA rba.applib.x',
            'DECLARE ... ;',
            'CREATE PROCEDURE Common_Utils() BEGIN',
            '  CALL Shared_Func(arg);',
            'END;' | Set-Content -Path "$TestRootPath\APPLIB_X\rba\applib\x\APPLibX.esql"

            New-Item -Path "$TestRootPath\APPLIB_Y\rba\applib\y" -ItemType Directory
            '<projectDescription>',
            '  <name>APPLIB_Y</name>',
            '  <projects>',
            '    <project>SHLIB_X</project>',
            '   </projects>',
            '</projectDescription>' | Set-Content -Path "$TestRootPath\APPLIB_Y\.project"
            'BROKER SCHEMA rba.applib.y',
            'DECLARE ... ;',
            'CREATE PROCEDURE Func_Utils() BEGIN',
            '  DECLARE out Character;',
            '  SET out = Shared_Func(arg).toUpperCase();',
            'END;' | Set-Content -Path "$TestRootPath\APPLIB_Y\rba\applib\y\APPLibY.esql"

            New-Item -Path "$TestRootPath\APP_X\rba\app\x" -ItemType Directory
            '<projectDescription>',
            '  <name>APP_X</name>',
            '  <projects>',
            '    <project>APPLIB_X</project>',
            '   </projects>',
            '</projectDescription>' | Set-Content -Path "$TestRootPath\APP_X\.project"
            'BROKER SCHEMA rba.app.x',
            'DECLARE ... ;',
            'CREATE DATABASE MODULE Test',
            'CREATE FUNCTION Main() RETURNS BOOLEAN BEGIN',
            '  CALL Common_Utils();',
            '  RETURN TRUE;',
            'END;',
            'END MODULE;' | Set-Content -Path "$TestRootPath\APP_X\rba\app\x\APP_X.esql"

            '<composition>',
            '  <nodes statement="esql://routine/rba.app.x#Test.Main">',
            '    <translation any_attributes/>',
            '  </nodes>',
            '</composition>' | Set-Content -Path "$TestRootPath\APP_X\rba\app\x\MF_APP.msgflow"

            $Output = (Get-IIBCallStack -RootName $TestRootName -Resource 'Shared_Func' 6>&1)
            
            $Output | Should -HaveCount 18
            (-Join $Output[0..3])   | Should -Be 'SHLIB_X\rba\lib\x\SharedLibX.esql:3:CREATE FUNCTION Shared_Func(IN p CHARACTER) RETURNS CHARACTER'
            (-Join $Output[4..7])   | Should -Be '    APPLIB_Y\rba\applib\y\APPLibY.esql:5:SET out = Shared_Func(arg).toUpperCase();'
            (-Join $Output[8..11])  | Should -Be '    APPLIB_X\rba\applib\x\APPLibX.esql:4:CALL Shared_Func(arg);'
            (-Join $Output[12..15]) | Should -Be '        APP_X\rba\app\x\APP_X.esql:5:CALL Common_Utils();'
            (-Join $Output[16..18]) | Should -Be '            APP_X\rba\app\x\MF_APP.msgflow'
        }
    }
}
