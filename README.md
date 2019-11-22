# PSIIB
**PSIIB** is a PowerShell module that provides commands for working with IBM Integration Bus.

## Overview
IBM Integration Bus is a great tool for integrating diverse business applications, independent of the message formats or protocols they support. However there are areas where IIB either lacks support or does not have an easy way during integration project development. 

**PSIIB** is intended to complement IBM Integration Bus to simplify the development work with it.

## Installation
### Direct Download
Download [PSIIB v1.2.0](https://github.com/hongstack/PSIIB/releases/download/1.2.0/PSIIB_1.2.0.zip), extracts the content under one of the following locations:
* `C:\Program Files\WindowsPowerShell\Modules` (*applies to all users, but may not be an option in some corporate environments*).
* `$env:USERPROFILE\Documents\WindowsPowerShell\Modules` (*applies to current user*).

### Manual Build
This option assumes [PSLocalModule](https://github.com/hongstack/PSLocalModule) is installed and configured.

When clone to any directory:
```PowerShell
git clone https://github.com/hongstack/PSIIB.git
Set-Location PSIIB
Install-LocalModule -Verbose -Whatif
Install-LocalModule
```

When clone to the `PSCodePath`:
```PowerShell
git clone https://github.com/hongstack/PSIIB.git <PSCodePath>
Install-LocalModule PSIIB -Verbose -Whatif
Install-LocalModule PSIIB
```

## Usage
### Set-IIBHome and Get-IIBHome
**IIB Home** is the directory where IIB is installed. It is required by the following commands:
* `Install-IIBApplication`
* `Enable-IIBFlowMonitoring`
* `Get-IIBFlowMonitoring`
* `Get-IIBStatus`
* `Start-IIB`

### Set-IIBRoot and Get-IIBRoot
**IIB Root** is the parent directory where all IIB projects reside in as direct children. `Set-IIBRoot` command associates a name (a.k.a *RootName*) with a path so that the name is resolved to the path when perform search in IIB project resources.

`Get-IIBRoot` on the other hand shows the path for a specified name, and lists all configured name/path pairs when `-ALL` parameter is used.

### Get-IIBCallStack
The command `Get-IIBCallStack` searches and prints the call stack for the specified resource. It requires *IIBRoot* to be configured via `Set-IIBRoot`. If there is only one *IIBRoot* configured, then it is used by default when executing `Get-IIBCallStack`.
```PowerShell
Get-IIBCallStack -Resource <Flow_or_Routine_Name>
Get-IIBCallStack -Resource <Flow_or_Routine_Name> -RootName <RootName>
```

### Install-IIBApplication
The command `Install-IIBApplication` installs IIB application onto the specified IIB node and server (Execution Group). It resolves the depending shared libraries and install them automatically if they are not available on the target server. This command requires both *IIBHome* and *IIBRoot* to be configured.
```PowerShell
Install-IIBApplication -AppName <AppName>
Install-IIBApplication -AppName <AppName> -RootName <RootName> -Exclusive -FlowMonitoring -Node <NodeName> -Server <ServerName>
```

### More Info
Use PowerShell's `Get-Command -Module PSIIB` to explore available commands, and `Get-Help <Cmdlet>` to find out the usage for each command.

## TODO
* Exclude the commented module/routine definitions and calls