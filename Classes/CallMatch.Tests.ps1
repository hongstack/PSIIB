using module .\CallMatch.psm1

Describe "call match class" -Tags ('CallMatch') {
    $AppRoot = 'TestDrive:\iib\projects1'

    $CallMatch = [CallMatch]::new(@{
        AppRoot  = "TestDrive:\IIB\PROJECTS1"
        FullPath = "$AppRoot\App1\path\file.ext"
    });

    It "Gets valid application path relative to root" {
        $CallMatch.AppPath | Should -Be 'App1\path\file.ext'
    }

    It "Gets valid app name" {
        $CallMatch.AppName | Should -Be 'App1'
    }

    It "Returns default depth of zero" {
        $CallMatch.Depth | Should -Be 0
    }
}

Describe "flow call match class" -Tags ('CallMatch', 'FlowCallMatch') {
    $AppRoot = 'TestDrive:\iib\projects1'
    
    $FlowCallMatch = [FlowCallMatch]::new(@{
        AppRoot  = "$AppRoot"
        FullPath = "$AppRoot\App1\path\file.msgflow"
        Depth   = 3
    })

    It "Detects the message flow" {
        $FlowCallMatch.IsMessageFlow() | Should -BeTrue
    }

    It "Returns the given depth" {
        $FlowCallMatch.Depth | Should -Be 3
    }

    It "Defines flow call pattern in message flow" {
        $FlowCallMatch.GetFlowCallPatternInFlow() | Should -Be 'xmi:type="path_file.msgflow'
    }
}
Describe "routine call match class" -Tags ('CallMatch', 'RoutineCallMatch') {
    $AppRoot = 'TestDrive:\iib\projects1'
    
    It "Defines module definition pattern" {
        [RoutineCallMatch]::PTN_MODULE_DEF | Should -BeExactly 'CREATE\s+\w+\s+MODULE\s+([\S]*)'
    }

    It "Defines rutine definition pattern" {
        [RoutineCallMatch]::PTN_ROUTINE_DEF | Should -BeExactly 'CREATE\s+(FUNCTION|PROCEDURE)\s+([^\s(]+)\s*\('
        $RoutineName = 'Any Name'
        [RoutineCallMatch]::GetRoutineDefPattern($RoutineName) | Should -BeExactly "CREATE\s+(FUNCTION|PROCEDURE)\s+$RoutineName\s*\("
    }
    
    It "Gets correct match info" {
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

    It "Gets routine call pattern in message flow" {
        $RoutineCallMatch = [RoutineCallMatch]::new(@{
            AppRoot  = "$AppRoot"
            FullPath = "$AppRoot\APP_X\rba\app\x\APP_X.esql"
            Routine = 'MyModule.Main'
            Line = 'CREATE FUNCTION Main () RETURNS BOOLEAN'
            LineNumber = '100'
        })

        $RoutineCallMatch.IsMainRoutine() | Should -Be $True
        $RoutineCallMatch.GetRoutineCallPatternInFlow() | Should -BeExactly 'esql://routine/rba.app.x#MyModule.Main'
    }

    It "Gets routine call pattern in routine" {
        $RoutineCallMatch = [RoutineCallMatch]::new(@{
            AppRoot  = "$AppRoot"
            FullPath = "$AppRoot\APP_X\rba\app\x\APP_X.esql"
            Routine = 'MyFunc'
            Line = 'CREATE FUNCTION MyFunc (IN param CHARACTER)'
            LineNumber = '100'
        })

        $RoutineCallMatch.GetRoutineCallPatternInRoutine() | Should -BeExactly '(?<!(FUNCTION|PROCEDURE))\s+MyFunc\s*\('
    }
}