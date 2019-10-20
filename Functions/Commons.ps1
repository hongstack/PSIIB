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
        [Parameter(Mandatory=$true, Position=0)][String]$IIBHome
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
        $E = [CmdletInvocationException]"Module not configured. Please use Set-IIBHome to configure"
        Write-Error -Exception $E -Category ObjectNotFound -ErrorAction Stop
    }

    $ModuleConfig = Get-ModuleConfig -Path $ModuleConfigPath
    $IIBHome = $ModuleConfig.IIBHome

    if ([String]::IsNullOrWhiteSpace($IIBHome)) {
        $E = [CmdletInvocationException]"IIBHome not set or is blank"
        Write-Error -Exception $E -Category InvalidData -ErrorAction Stop
    }

    Validate-IIBHome -IIBHome $IIBHome
    $IIBHome
}

function Validate-IIBHome ($IIBHome) {
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

function Get-ModuleConfigPath {
    $PSModuleFullName -replace 'psm1', 'json'
}

function Get-ModuleConfig ($Path) {
    try {
        Get-Content -Path $Path -Raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Error $_ -ErrorAction Stop
    }
}