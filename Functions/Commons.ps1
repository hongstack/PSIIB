using namespace System.Management.Automation

<#
.SYNOPSIS
Sets the IIB installation home where iib.cmd is located in.

.DESCRIPTION
The Set-IIBHome specifies where the IBM Integration Bus is installed.

It is required for running IIB built-in commands such as mqsi commands.

.PARAMETER IIBHome
Specifies the path to the IIB installation home.
#>
function Set-IIBHome {
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, Mandatory=$true)]
        [String]$IIBHome
    )

    Validate-IIBHome -IIBHome $IIBHome

    $ModuleConfigPath = Get-ModuleConfigPath
    $ModuleConfigName = $ModuleConfigPath | Split-Path -Leaf
    if (Test-Path -Path $ModuleConfigPath) {
        $ModuleConfig = Get-ModuleConfig -Path $ModuleConfigPath
        Write-Verbose "Update module configuration: $ModuleConfigName"
    } else {
        $ModuleConfig = @{}
        Write-Verbose "Create module configuration: $ModuleConfigName"
    }
    $ModuleConfig.IIBHome = $IIBHome
    $ModuleConfig | ConvertTo-Json | Set-Content $ModuleConfigPath
}

<#
.SYNOPSIS
Returns the already-set IIB installation home.
#>
function Get-IIBHome {
    [CmdletBinding()]
    Param()

    $ModuleConfigPath = Get-ModuleConfigPath
    if (-not (Test-Path -Path $ModuleConfigPath)) {
        $E = [CmdletInvocationException]"Module not configured"
        Write-Error -Exception $E -Category ObjectNotFound -ErrorAction Stop
    }

    $ModuleConfig = Get-ModuleConfig -Path $ModuleConfigPath
    $IIBHome = $ModuleConfig.IIBHome

    Validate-IIBHome -IIBHome $IIBHome
    $IIBHome
}

function Validate-IIBHome ($IIBHome) {
    if ([String]::IsNullOrWhiteSpace($IIBHome)) {
        $E = [CmdletInvocationException]"IIBHome not set or is blank"
        Write-Error -Exception $E -Category InvalidData -ErrorAction Stop
    }
    
    if (-not (Test-Path -Path $IIBHome)) {
        $E = [CmdletInvocationException]"IIBHome [$IIBHome] does not exist"
        Write-Error -Exception $E -Category InvalidData -ErrorAction Stop
    }

    $IIBCmd = Join-Path -Path $IIBHome -ChildPath 'iib.cmd'
    if (-not (Test-Path -Path $IIBCmd)) {
        $E = [CmdletInvocationException]"IIBHome is invalid. Script [$IIBCmd] does not exist"
        Write-Error -Exception $E -Category InvalidData -ErrorAction Stop
    }
}

<#
.SYNOPSIS
Sets the root location where IIB projects reside.

.DESCRIPTION
The Set-IIBRoot associates a name with the root loation where IIB projects reside.

.PARAMETER RootName
Specifies the name for the root directory.

.PARAMETER RooPath
Specifies the path for the root directory.

.Example
Set-IIBRoot -RootName App1 -RootPath C:\Dev\App1

This commands will associate the name App1 to the path C:\Dev\App1.
#>
function Set-IIBRoot {
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, Mandatory=$true)]
        [String]$RootName,
        
        [Parameter(Position=1, Mandatory=$true)]
        [String]$RootPath
    )

    Validate-IIBRootPath -RootPath $RootPath

    $ModuleConfigPath = Get-ModuleConfigPath
    $ModuleConfigName = $ModuleConfigPath | Split-Path -Leaf
    if (Test-Path -Path $ModuleConfigPath) {
        $ModuleConfig = Get-ModuleConfig -Path $ModuleConfigPath
        Write-Verbose "Update module configuration: $ModuleConfigName"
    } else {
        $ModuleConfig = @{}
        Write-Verbose "Create module configuration: $ModuleConfigName"
    }

    if ($ModuleConfig.IIBRoot) {
        $ModuleConfig.IIBRoot.$RootName = $RootPath
    } else {
        $ModuleConfig.IIBRoot = @{ $RootName = $RootPath }
    }
    $ModuleConfig | ConvertTo-Json | Set-Content $ModuleConfigPath
}

<#
.SYNOPSIS
Returns the root directory or root directories.

.DESCRIPTION
If the root name is specified, returns the root directory that is associated
with the specified name, or $null if not set before.

If the root name is not specified and there is only one direcotry set, that 
one is returned. If the root name is not specified but there are mulitple 
directories set, exception will be thrown.

.PARAMETER RootName
Specifies the root name that a root direcotry is associated with.
If omitted and there is only one root directory, that one is returned.

.PARAMETER ALL
Specifies that all pre-set root directories should be returned.
#>
function Get-IIBRoot {
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    Param(
        [Parameter(ParameterSetName = 'ByName', Position = 0)]
        [String]$RootName,
        
        [Parameter(ParameterSetName = 'ALL')]
        [Switch]$ALL
    )
    
    $ModuleConfigPath = Get-ModuleConfigPath
    if (-not (Test-Path -Path $ModuleConfigPath)) {
        $E = [CmdletInvocationException]"Module not configured"
        Write-Error -Exception $E -Category ObjectNotFound -ErrorAction Stop
    }

    $ModuleConfig = Get-ModuleConfig -Path $ModuleConfigPath

    if ('ByName' -eq $PSCmdlet.ParameterSetName) {
        if ($RootName) {
            $RootPath = $ModuleConfig.IIBRoot.$RootName
        } elseif ($ModuleConfig.IIBRoot.Count -eq 1) {
            $RootPath = $ModuleConfig.IIBRoot.Values | Select -First 1
        } elseif ($ModuleConfig.IIBRoot.Count -gt 1) {
            $E = [PSArgumentException]"Multiple paths exist, root name required"
            Write-Error -Exception $E -Category InvalidArgument -ErrorAction Stop
        }

        Validate-IIBRootPath -RootPath $RootPath
        $RootPath
    } elseif ('ALL' -eq $PSCmdlet.ParameterSetName -and $ALL) {
        if ($ModuleConfig.IIBRoot) {
            $ModuleConfig.IIBRoot.GetEnumerator() | Select @{N="RootName"; E={$_.Key}}, @{N="RootPath"; E={$_.Value}}
        }
    } else {
        $E = [PSArgumentException]"Unknown parameter set name: $($PSCmdlet.ParameterSetName)"
        Write-Error -Exception $E -Category InvalidArgument -ErrorAction Stop
    }
}

function Validate-IIBRootPath ($RootPath) {
    if ([String]::IsNullOrWhiteSpace($RootPath)) {
        $E = [CmdletInvocationException]"IIBRoot not set or is blank"
        Write-Error -Exception $E -Category InvalidData -ErrorAction Stop
    }
    
    if (-not (Test-Path -Path $RootPath)) {
        $E = [CmdletInvocationException]"Root path [$RootPath] does not exist"
        Write-Error -Exception $E -Category InvalidData -ErrorAction Stop
    }
}

function Get-ModuleConfigPath {
    $PSModuleFullName -replace 'psm1', 'json'
}

function Get-ModuleConfig ($Path){
    # https://replicajunction.github.io/2017/07/17/converting-json-to-hashtable/
    try {
        Add-Type -AssemblyName "System.Web.Extensions" -ErrorAction Stop
        $JSSerializer = [System.Web.Script.Serialization.JavaScriptSerializer]::new()
        $JsonData = Get-Content -Path $Path -Raw
        $JSSerializer.Deserialize($JsonData,'Hashtable')
    } catch {
        throw
    }
}