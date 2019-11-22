<#
.SYNOPSIS
Installs IIB application to the specified node and server, from the given location.

.DESCRIPTION
The Install-IIBApplication creates new BAR file and deploys it onto IIB server. 

It starts with resolving the required dependencies and deploying them first if 
they are not available on IIB server, recusively.

.PARAMETER AppName
Specifies the application name that to be installed.

.PARAMETER RootName
Specifies the root name that is set via Set-IIBRoot.
If omitted and there is only one root directory, that one is used.

.PARAMETER Exclusive
Specifies whether to remove irrelavant applications and libraries.

.PARAMETER FlowMonitoring
Specifies whether to enable flow monitoring on the target IIB server.

.PARAMETER Node
Specifies the target IIB node, defaults to "TESTNODE_$env:USERNAME".

.PARAMETER Server
Specifies the target IIB server, defaults to "default".

.Example
Install-IIBApplication App1

Install the application [App1] onto default IIB node and server, from the default 
root location assuming there is one IIB root configured via Set-IIBRoot.

.Example
Install-IIBApplication App1 Root1 -Exclusive -FlowMonitoring -Node TestNode

Install the application [App1] onto IIB TestNode and default server, from the location 
defined by Root1. This command also remove libraries and applications not related to 
[App1] and enables the flow monitoring after the installation.
#>
function Install-IIBApplication {
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)]
        [String] $AppName,

        [Parameter(Position=1)]
        [String] $RootName,
        
        [Parameter()]
        [Switch] $Exclusive,
        
        [Parameter()]
        [Switch] $FlowMonitoring,

        [Parameter()]
        [Alias('Broker')]
        [String] $Node = "TESTNODE_$env:USERNAME",

        [Parameter()]
        [Alias('EG')]
        [String] $Server = 'default'
    )

    BEGIN {
        Start-IIB -Node $Node -Server $Server
        $RootLocation = Get-IIBRoot -RootName $RootName
        $DeployedResources = Get-IIBDeployedResources -Node $Node -Server $Server
        $DeployedApps = $DeployedResources[0]
        $DeployedLibs = $DeployedResources[1]
        $ProcessedApps = @()
        $ProcessedLibs = @()
    }
    PROCESS {
        $Descriptor = $RootLocation | Join-Path -ChildPath $AppName | Join-Path -ChildPath 'application.descriptor'
        if (Test-Path -Path $Descriptor) {
            $NS = @{ns1="http://com.ibm.etools.mft.descriptor.base"}
            $Libs = (Select-Xml -Path $Descriptor -XPath '//ns1:libraryName' -Namespace $NS).Node.InnerXml
            
            $NewLibs = $Libs.where{$DeployedLibs -notcontains $_}
            if ($NewLibs.Count -gt 0) {
                $NewLibs | New-IIBBarFile -RootLocation $RootLocation | Install-IIBResource -Node $Node -Server $Server
                $DeployedLibs  += $NewLibs
                $ProcessedLibs += $NewLibs
            }
            
            $AppName  | New-IIBBarFile -RootLocation $RootLocation | Install-IIBResource -Node $Node -Server $Server
            $ProcessedApps += $AppName
        } else {
            Write-Error -Message "$AppName is not an IIB application" -Category InvalidArgument
        }
    }
    END {
        if ($Exclusive) {
            $DeployedApps.where{$ProcessedApps -notcontains $_} | UnInstall-IIBResource -Node $Node -Server $Server
            $DeployedLibs.where{$ProcessedLibs -notcontains $_} | UnInstall-IIBResource -Node $Node -Server $Server
        }
        if ($FlowMonitoring) {
            Enable-IIBFlowMonitoring -Node $Node -Server $Server
        }
    }
}

<#
.SYNOPSIS
Gets the running status of IIB node and server.

.DESCRIPTION
The following value is returned to indicate the status of IIB node and server.
 0 - both IIB node and server are running
 1 - IIB node is stopped
 2 - IIB node is running but IIB server is stopped
-1 - Unknown error occurred

.PARAMETER Node
Specifies the target IIB node, defaults to "TESTNODE_$env:USERNAME".

.PARAMETER Server
Specifies the target IIB server, defaults to "default".
#>
function Get-IIBStatus {
    [CmdletBinding()]
    [OutputType([Int])]
    Param(
        [Parameter()]
        [Alias('Broker')]
        [String] $Node = "TESTNODE_$env:USERNAME",

        [Parameter()]
        [Alias('EG')]
        [String] $Server = 'default'
    )

    $Result = "mqsireportproperties $Node -e $Server -o ExecutionGroup -a" | Invoke-IIBCommand -ErrorVariable ErrMsg -ErrorAction SilentlyContinue

    if ($ErrMsg.Count -eq 0) {
        0
        $Result | ForEach-Object { Write-Verbose $_ }
    } elseif ($ErrMsg -like 'BIP8019E:*') { # IIB Node stopped
        1
        $ErrMsg | ForEach-Object { Write-Verbose $_ }
    } elseif ($ErrMsg -like 'BIP2851E:*') { # IIB Server stopped
        2
        $ErrMsg | ForEach-Object { Write-Verbose $_ }
    } else {
        -1
        $ErrMsg | ForEach-Object { Write-Error $_ }
    }
}

<#
.SYNOPSIS
Starts IIB node and/or server.

.DESCRIPTION
This command will start IIB node and IIB server if they are not running.
There is no action if both of IIB node and server are started.

.PARAMETER Node
Specifies the target IIB node, defaults to "TESTNODE_$env:USERNAME".

.PARAMETER Server
Specifies the target IIB server, defaults to "default".
#>
function Start-IIB {
    [CmdletBinding()]
    Param(
        [Parameter()]
        [Alias('Broker')]
        [String] $Node = "TESTNODE_$env:USERNAME",

        [Parameter()]
        [Alias('EG')]
        [String] $Server = 'default'
    )

    $Status = Get-IIBStatus -Node $Node -Server $Server
    if ($Status -eq 1) {
        Start-IIBNode -Node $Node
        $Status = Get-IIBStatus -Node $Node -Server $Server
    }

    if ($Status -eq 2) {
        Start-IIBServer -Node $Node -Server $Server
    }
}

function Start-IIBNode {
    [CmdletBinding()]
    Param(
        [Parameter()]
        [Alias('Broker')]
        [String] $Node = "TESTNODE_$env:USERNAME"
    )

    Write-Host "Starting IIB Node [$Node]" -ForegroundColor Cyan
    "mqsistart $Node" | Invoke-IIBCommand | ForEach-Object { Write-Verbose $_ }
    Write-Host "Started  IIB Node [$Node]" -ForegroundColor Cyan
}

function Start-IIBServer {
    [CmdletBinding()]
    Param(
        [Parameter()]
        [Alias('Broker')]
        [String] $Node = "TESTNODE_$env:USERNAME",

        [Parameter()]
        [Alias('EG')]
        [String] $Server = 'default'
    )

    Write-Host "Starting IIB Server [$Server@$Node]" -ForegroundColor Cyan
    "mqsistartmsgflow $Node -e $Server" | Invoke-IIBCommand | ForEach-Object { Write-Verbose $_ }
    Write-Host "Started  IIB Server [$Server@$Node]" -ForegroundColor Cyan
}

function Get-IIBDeployedResources {
    [CmdletBinding()]
    Param(
        [Parameter()]
        [Alias('Broker')]
        [String] $Node = "TESTNODE_$env:USERNAME",

        [Parameter()]
        [Alias('EG')]
        [String] $Server = 'default'
    )
    
    $Apps = @()
    $Libs = @()
    "mqsilist $Node -e $Server" | Invoke-IIBCommand | ForEach-Object {
        if($_ -match "Application '([^']+)'") {
            $Apps += $Matches[1]
        } elseif ($_ -match "Shared library '([^']+)'") {
            $Libs += $Matches[1]
        }
    }
    $Apps, $Libs
}

function New-IIBBarFile {
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)]
        [String] $Resource,

        [Parameter(Position=1, Mandatory=$true)]
        [String] $RootLocation,

        [Parameter()]
        [String] $BarLocation = $env:TEMP
    )

    PROCESS {
        $BarFileName = "$Resource.bar"
        Write-Host "Creating BAR file [$BarFileName]" -ForegroundColor Cyan
        $BarFullName = Join-Path -Path $BarLocation -ChildPath $BarFileName
        "mqsipackagebar -w $RootLocation -a $BarFullName -k $Resource" | Invoke-IIBCommand | ForEach-Object { Write-Verbose $_ }
        Write-Host "Created  BAR file [$BarFileName]" -ForegroundColor Cyan
        $BarFullName
    }
}

function Install-IIBResource {
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)]
        [String] $BarFullName,

        [Parameter()]
        [Alias('Broker')]
        [String] $Node = "TESTNODE_$env:USERNAME",

        [Parameter()]
        [Alias('EG')]
        [String] $Server = 'default'
    )

    PROCESS {
        $BarFileName = Split-Path $BarFullName -Leaf
        Write-Host "Installing [$BarFileName] onto $Server@$Node" -ForegroundColor Cyan
        "mqsideploy $Node -e $Server -a $BarFullName" | Invoke-IIBCommand | ForEach-Object { Write-Verbose $_ }
        Write-Host "Installed  [$BarFileName] onto $Server@$Node" -ForegroundColor Cyan
    }
}

function UnInstall-IIBResource {
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)]
        [String] $Resource,

        [Parameter()]
        [Alias('Broker')]
        [String] $Node = "TESTNODE_$env:USERNAME",

        [Parameter()]
        [Alias('EG')]
        [String] $Server = 'default'
    )

    PROCESS {
        Write-Host "UnInstalling [$Resource] from $Server@$Node" -ForegroundColor Cyan
        "mqsideploy $Node -e $Server -d $Resource" | Invoke-IIBCommand | ForEach-Object { Write-Verbose $_ }
        Write-Host "UnInstalled  [$Resource] from $Server@$Node" -ForegroundColor Cyan
    }
}

<#
.SYNOPSIS
Enables the monitoring of message flows on IIB node and server.

.DESCRIPTION
Enables the monitoring of message flows on IIB node and server.

.PARAMETER Node
Specifies the target IIB node, defaults to "TESTNODE_$env:USERNAME".

.PARAMETER Server
Specifies the target IIB server, defaults to "default".
#>
function Enable-IIBFlowMonitoring {
    [CmdletBinding()]
    Param(
        [Parameter()]
        [Alias('Broker')]
        [String] $Node = "TESTNODE_$env:USERNAME",

        [Parameter()]
        [Alias('EG')]
        [String] $Server = 'default'
    )

    Write-Host "Enabling flow monitoring on $Server@$Node" -ForegroundColor Cyan
    "mqsichangeflowmonitoring $Node -e $Server -c active -j" | Invoke-IIBCommand | ForEach-Object { Write-Verbose $_ }
    Write-Host "Enabled  flow monitoring on $Server@$Node" -ForegroundColor Cyan
}

<#
.SYNOPSIS
Reports the monitoring of message flows on IIB node and server.

.DESCRIPTION
Reports the monitoring of message flows on IIB node and server.

.PARAMETER Node
Specifies the target IIB node, defaults to "TESTNODE_$env:USERNAME".

.PARAMETER Server
Specifies the target IIB server, defaults to "default".
#>
function Get-IIBFlowMonitoring {
    [CmdletBinding()]
    Param(
        [Parameter()]
        [Alias('Broker')]
        [String] $Node = "TESTNODE_$env:USERNAME",

        [Parameter()]
        [Alias('EG')]
        [String] $Server = 'default'
    )

    "mqsireportflowmonitoring $Node -e $Server" | Invoke-IIBCommand | ForEach-Object { Write-Verbose $_ }
}

function Invoke-IIBCommand {
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)]
        [String] $IIBCmd
    )

    BEGIN {
        $IIB_Home = Get-IIBHome
    }

    PROCESS {
        $Result = & $env:ComSpec /C "@set IIB_BANNER=1 & $IIB_HOME\iib.cmd $IIBCmd"
        if ($LASTEXITCODE -ne 0) {   
            Write-Error -Message ($Result -join "`n") -Category InvalidOperation
        } else {
            $Result.where{-not [String]::IsNullOrWhiteSpace($_)}
        }
    }
}