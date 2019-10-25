class CallMatch {
    [ValidateNotNullOrEmpty()][String] $AppRoot
    [ValidateNotNullOrEmpty()][String] $FullPath
    [ValidateRange(0, 10)][Int32] $Depth
    [String] $AppPath # Relative path to AppRoot
    [String] $AppName

    CallMatch($MatchInfo) {
        $this.AppRoot  = $MatchInfo.AppRoot
        $this.FullPath = $MatchInfo.FullPath
        $this.Depth    = $MatchInfo.Depth
        $this.AppPath  = $this.FullPath.Substring($this.AppRoot.Length + 1)
        $this.AppName  = $this.AppPath.Split('\')[0]
    }
}

class FlowCallMatch : CallMatch {
    FlowCallMatch($MatchInfo) : base($MatchInfo) {}
    
    [Boolean] IsMessageFlow() {
        return $this.FullPath.EndsWith('msgflow')
    }

    [String] GetFlowCallPatternInFlow() {
        $FileQName = $this.AppPath.SubString($this.AppName.Length + 1)
        return ('xmi:type="{0}' -f ($FileQName.Replace('\', '_')))
    }

    [Void] Print() {
        $FileName = Split-Path $this.FullPath -Leaf
        Write-Host ('{0}{1}' -f ('    ' * $this.Depth), $this.AppPath.Replace($FileName, '')) -NoNewline
        Write-Host $FileName -ForegroundColor Cyan
    }
}

class RoutineCallMatch : CallMatch {
    static [String] $PTN_MODULE_DEF  = 'CREATE\s+\w+\s+MODULE\s+([\S]*)'
    static [String] $PTN_ROUTINE_DEF = 'CREATE\s+(FUNCTION|PROCEDURE)\s+([^\s(]+)\s*\('
    static [String] GetRoutineDefPattern($Routine) {
        return "CREATE\s+(FUNCTION|PROCEDURE)\s+$Routine\s*\("
    }

    [ValidateNotNullOrEmpty()][String] $Routine
    [ValidateNotNullOrEmpty()][String] $Line
    [Int32] $LineNumber

    RoutineCallMatch($MatchInfo) : base($MatchInfo) {
        $this.Routine    = $MatchInfo.Routine
        $this.Line       = $MatchInfo.Line
        $this.LineNumber = $MatchInfo.LineNumber
    }

    [Boolean] IsMainRoutine() {
        return $this.Routine.EndsWith('.Main')
    }

    [String] GetRoutineCallPatternInFlow() {
        $FileQName = $this.AppPath.SubString($this.AppName.Length + 1)
        if ($FileQName.IndexOf('\') -ne -1) {
            $Package = Split-Path $FileQName -Parent
            $Package = $Package.Replace('\', '.')
        } else {
            $Package = ''
        }
        return ('esql://routine/{0}#{1}' -f $Package, $this.Routine)
    }

    [String] GetRoutineCallPatternInRoutine() {
        return ('(?<!(FUNCTION|PROCEDURE))\s+{0}\s*\(' -f $this.Routine)
    }

    [Void] Print() {
        $FileName = Split-Path $this.FullPath -Leaf
        Write-Host ('{0}{1}' -f ('    ' * $this.Depth), $this.AppPath.Replace($FileName,'')) -NoNewline
        Write-Host $FileName -ForegroundColor Cyan -NoNewline
        Write-Host (':{0}:' -f $this.LineNumber) -ForegroundColor Magenta -NoNewline
        Write-Host $this.Line.Trim()
    }
}