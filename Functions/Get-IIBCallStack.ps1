using namespace System.Collections.Generic
using namespace System.Management.Automation

<#
.SYNOPSIS
Searches and prints the call stack for the specified resource.

.DESCRIPTION
The Get-IIBCallStack searches for all the invocation or uses footprint
for the specified resource and prints the result in a tree format.

It supports searching for the call stack for the ESQL functions, modules,
message sub-flows and flows.

.PARAMETER Resource
Specifies the resource that is called or used.

The type of resource is inferred from the specified resource:
- Message flow is assumed if the resource ends with '.subflow' or '.msgflow'
- ESQL routine is assumed otherwise

.PARAMETER RootName
Specifies the root name that is set via Set-IIBRoot.
If omitted and there is only one root directory, that one is used.

.Example
Get-IIBCallStack -Resource The_shared_flow.subflow -RootName PreSetName

This commands will return the message flow call hierarchy from The_shared_flow.subflow.

.Example
Get-IIBCallStack -Resource SharedFunctionDef

This commands will return the function call hierarchy from SharedFunctionDef.
#>
function Get-IIBCallStack {
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, Mandatory=$true)] [String]$Resource,
        [Parameter(Position=1)] [String]$RootName
    )
    
    Init-ScriptVariables -RootName $RootName
    if (-not $Script:APP_LIST) { return }

    if ($Resource -like '*.???flow') {
        Get-FlowCallStack -FlowName $Resource
    } else {
        Get-RoutineCallStack -Routine $Resource
    }
}
Set-Alias -Name iibcs -Value Get-IIBCallStack

function Init-ScriptVariables($RootName) {
    $Script:APP_ROOT = Get-AppRoot -RootName $RootName
    $Script:APP_LIST = Get-AppList -AppRoot  $Script:APP_ROOT # [System.IO.DirectoryInfo[]]
    $Script:LIB_REFS = Get-LibRefs -AppList  $Script:APP_LIST # [Hashtable[[String],[HashSet]]]
}

function Get-AppRoot($RootName) {
    try {
        $RootPath = Get-IIBRoot -RootName $RootName
    } catch {
        throw $_
    }
    if (-not $RootPath) {
        $PSCmdlet.ThrowTerminatingError(
            [ErrorRecord]::new(
                [PSArgumentException]"No path is defined for $RootName",
                'PSIIB.Init-AppRoot',
                [ErrorCategory]::InvalidArgument,
                $null
            )
        )
    }
    if (-not (Test-Path -Path $RootPath)) {
        $PSCmdlet.ThrowTerminatingError(
            [ErrorRecord]::new(
                [ItemNotFoundException]"Path does not exist: $RootPath",
                'PSIIB.Init-AppRoot',
                [ErrorCategory]::ObjectNotFound,
                $null
            )
        )
    }
    return $RootPath
}

function Get-AppList($AppRoot) {
    return $AppRoot | Get-ChildItem -Directory | Where {Test-Path "$($_.FullName)\.project"} | ForEach-Object {
        $App = $_
        do {
            $_.FullName | Get-ChildItem -Recurse -File | ForEach-Object {
                if (($_.Name -like '*.esql') -or ($_.Name -like '*.???flow')) {
                    $App
                    break
                }
            }
        } while ($false)
    }
}

function Get-LibRefs($AppList) {
    if (-not $AppList) { return }

    $LibRefs = @{}
    $AppList | ForEach-Object {
        $AppName = $_.Name
        Select-String -Path "$($_.FullName)\.project" -Pattern '<project>([^<]*)</project>' | ForEach-Object {
            $LibName = $_.Matches.Groups[1].Value
            $Refs = $LibRefs[$LibName]
            if($null -eq $Refs) {
                $Refs = [HashSet[string]]::new()
                $LibRefs[$LibName] = $Refs
            }
            [Void]$Refs.Add($AppName)
        }
    }

    $Stack = [Stack[String]]::new()
    $LibRefs.Keys | ForEach-Object {
        $Refs = $LibRefs[$_]
        $Stack.Clear()
        foreach($Ref in $Refs) { $Stack.Push($Ref) }
        while ($Stack.Count -ne 0) {
            $Current = $Stack.Pop()
            $CurrentRefs = $LibRefs[$Current]
            if ($null -ne $CurrentRefs) {
                foreach($Ref in $CurrentRefs) {
                    $Stack.Push($Ref)
                    [Void] $Refs.Add($Ref)
                }
            }
        }
    }

    return $LibRefs
}

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
        $this.AppPath  = $this.FullPath.Replace($this.AppRoot, '').Substring(1)
        $this.AppName  = $this.AppPath.Split('\')[0]
    }
}

class FlowCallMatch : CallMatch {
    FlowCallMatch($MatchInfo) : base($MatchInfo) {}
    
    [Boolean] IsMessageFlow() {
        return $this.FullPath.EndsWith('msgflow')
    }

    [String] GetFlowCallPatternInFlow() {
        $FileQName = $this.AppPath.Replace($this.AppName, '').SubString(1)
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
        $FileQName = $this.AppPath.Replace($this.AppName, '').SubString(1)
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

function Get-FlowCallStack($FlowName) {
    $Script:APP_LIST.FullName | Get-ChildItem -Recurse -File -Filter "$FlowName" | ForEach-Object {
        Get-FlowCallStackImpl -FullPath $_.FullName
    }
}

function Get-FlowCallStackImpl($FullPath, $Depth) {
    $Stack = [Stack[FlowCallMatch]]::new()
    $Stack.Push([FlowCallMatch]::new(@{
        AppRoot = $Script:APP_ROOT
        FullPath = $FullPath
        Depth = $Depth
    }))

    while($Stack.Count -gt 0) {
        $CM = $Stack.Pop()
        $CM.Print()
        if ($CM.IsMessageFlow()) { continue }

        $AppsToSearch = Get-SearchScope -AppName $CM.AppName
        $FoundFiles = $AppsToSearch | Search-File -Filter *.*flow -Pattern $CM.GetFlowCallPatternInFlow()
        for ($i = $FoundFiles.Count - 1; $i -ge 0; $i--) {
            $Stack.Push([FlowCallMatch]::new(@{
                AppRoot = $Script:APP_ROOT
                FullPath = $FoundFiles[$i].Path
                Depth = $CM.Depth + 1
            }))
        }
    }
}

function Get-RoutineCallStack($Routine) {
    # TODO: Exclude commented call
    $Stack = [Stack[RoutineCallMatch]]::new()
    $Script:APP_LIST.FullName | Search-File -Filter *.esql -Pattern ([RoutineCallMatch]::GetRoutineDefPattern($Routine)) | ForEach-Object {
        $Stack.Push([RoutineCallMatch]::new(@{
            AppRoot = $Script:APP_ROOT
            FullPath = $_.Path
            Routine = $Routine
            Line = $_.Line
            LineNumber = $_.LineNumber
        }))
    }

    while ($Stack.Count -gt 0) {
        $CM = $Stack.Pop()
        $CM.Print()
        if ($CM.IsMainRoutine()) {
            $AppsToSearch = Get-SearchScope -AppName $CM.AppName
            $FoundFiles = $AppsToSearch | Search-File -Filter *.*flow -Pattern $CM.GetRoutineCallPatternInFlow()
            foreach ($File in $FoundFiles) {
                Get-FlowCallStackImpl -FullPath $File.Path -Depth ($CM.Depth + 1)
            }
            continue
        }

        $AppsToSearch = Get-SearchScope -AppName $CM.AppName
        $FoundFiles = $AppsToSearch | Search-File -Filter *.esql -Pattern $CM.GetRoutineCallPatternInRoutine()
        foreach ($File in $FoundFiles) {
            $LineNum = 0
            Get-Content -Path $File.Path | ForEach-Object { # Loop each line
                $LineNum++
                if ($_ -match [RoutineCallMatch]::PTN_MODULE_DEF) {
                    $CurrentModule = $Matches[1]
                } elseif ($_ -match [RoutineCallMatch]::PTN_ROUTINE_DEF) {
                    $CurrentRoutine = $Matches[2]
                    if ($CurrentRoutine -eq 'Main') {
                        $CurrentRoutine = "$CurrentModule.Main"
                    }
                } elseif ($_ -match $CM.GetRoutineCallPatternInRoutine()) { # Found call
                    $Stack.Push([RoutineCallMatch]::new(@{
                        AppRoot = $Script:APP_ROOT
                        FullPath = $File.Path
                        Routine = $CurrentRoutine
                        Line = $_
                        LineNumber = $LineNum
                        Depth = $CM.Depth + 1
                    }))
                }
            }
        }
    }
}

function Get-SearchScope($AppName) {
    $AppsToSearch = @($AppName)
    $Refs = $Script:LIB_REFS[$AppName]
    if ($null -ne $Refs) {
        $AppsToSearch += $Refs
    }
    $AppsToSearch | ForEach-Object {Join-Path -Path $Script:APP_ROOT -ChildPath $_}
}

function Search-File {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)] [String]$SearchPath,
        [Parameter(Mandatory = $true)][String] $Filter,
        [Parameter(Mandatory = $true)][String] $Pattern
    )
    
    PROCESS {
        $SearchPath | Get-ChildItem -Recurse -File -Filter $Filter | Select-String -Pattern $Pattern -List
    }
}