
function Install-IIBApplication {
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)]
        [String] $AppName,

        [Parameter(Position=1)]
        [String] $RootName,

        [Parameter()]
        [Alias('Broker')]
        [String] $Node = "TESTNODE_$env:USERNAME",

        [Parameter()]
        [Alias('EG')]
        [String] $Server = 'default'
    )

    BEGIN {
        $RootLocation = Get-AppRoot -RootName $RootName
        # TODO Start IIB Node and Server if not running
        $DeployedResources = Get-IIBDeployedResources -Node $Node -Server $Server
        $DeployedApps = $DeployedResources[0]
        $DeployedLibs = $DeployedResources[1]
    }

    PROCESS {
        $AppDescriptor = $RootLocation | Join-Path -ChildPath $AppName | Join-Path -ChildPath 'application.descriptor'
        if (Test-Path $AppDescriptor) {
            $NameSpace = @{ns1="http://com.ibm.etools.mft.descriptor.base"}
            $Libs = (Select-Xml -Path $AppDescriptor -XPath '//ns1:libraryName' -Namespace $NameSpace).Node.InnerXml
            $Libs.where{$DeployedLibs -notcontains $_} | New-IIBBarFile -RootLocation $RootLocation | Install-IIBResource -Node $Node -Server $Server
            $DeployedLibs = $DeployedLibs.where{$Libs -notcontains $_}
        }
        $AppName  | New-IIBBarFile -RootLocation $RootLocation | Install-IIBResource -Node $Node -Server $Server
        $DeployedApps = $DeployedApps.where{$_ -ne $AppName}
    }

    END {
        $DeployedApps | UnInstall-IIBResource -Node $Node -Server $Server
        $DeployedLibs | UnInstall-IIBResource -Node $Node -Server $Server
        Enable-IIBFlowMonitoring -Node $Node -Server $Server
    }
}

function Get-IIBDeployedResources {
    [CmdletBinding()]
    Param(
        [Parameter()] [Alias('Broker')] [String] $Node = "TESTNODE_$env:USERNAME",
        [Parameter()] [Alias('EG')] [String] $Server = 'default'
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
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [String] $Resource,
        [Parameter(Position=1, Mandatory=$true)] [String] $RootLocation,
        [Parameter()] [String] $BarLocation = $env:TEMP
    )

    PROCESS {
        $BarFullName = Join-Path -Path $BarLocation -ChildPath "$Resource.bar"
        "mqsipackagebar -w $RootLocation -a $BarFullName -k $Resource" | Invoke-IIBCommand | ForEach-Object { Write-Verbose $_ }
        $BarFullName
    }
}

function Install-IIBResource {
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)]
        [String] $BarFullName,

        [Parameter()] [Alias('Broker')]
        [String] $Node = "TESTNODE_$env:USERNAME",

        [Parameter()] [Alias('EG')]
        [String] $Server = 'default'
    )

    PROCESS {
        "mqsideploy $Node -e $Server -a $BarFullName" | Invoke-IIBCommand | ForEach-Object { Write-Verbose $_ }
    }
}

function UnInstall-IIBResource {
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)]
        [String] $Resource,

        [Parameter()] [Alias('Broker')]
        [String] $Node = "TESTNODE_$env:USERNAME",

        [Parameter()] [Alias('EG')]
        [String] $Server = 'default'
    )

    PROCESS {
        "mqsideploy $Node -e $Server -d $Resource" | Invoke-IIBCommand | ForEach-Object { Write-Verbose $_ }
    }
}

function Enable-IIBFlowMonitoring {
    [CmdletBinding()]
    Param(
        [Parameter()] [Alias('Broker')]
        [String] $Node = "TESTNODE_$env:USERNAME",

        [Parameter()] [Alias('EG')]
        [String] $Server = 'default'
    )

    "mqsichangeflowmonitoring $Node -e $Server -c active -j" | Invoke-IIBCommand | ForEach-Object { Write-Verbose $_ }
}

function Get-IIBFlowMonitoring {
    [CmdletBinding()]
    Param(
        [Parameter()] [Alias('Broker')]
        [String] $Node = "TESTNODE_$env:USERNAME",

        [Parameter()] [Alias('EG')]
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
        }
        $Result.where{-not [String]::IsNullOrWhiteSpace($_)}
    }
}