# PSIIB
**PSIIB** is a PowerShell module that provides commands for working with IBM Integration Bus.

## Overview
IBM Integration Bus Toolkit does not support navigating between message flows and ESQL code during development. **PSIIB** is intended to bridge this gap and simplify the development work with IBM Integration Bus.

## Installation
### Direct Download
Download [PSIIB v1.1.0](https://github.com/hongstack/PSIIB/releases/download/1.1.0/PSIIB_1.1.0.zip), extracts the content under one of the following locations:
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
### Set-IIBRoot and Get-IIBRoot
**IIB Root** is the parent directory where all IIB projects reside in as direct children. `Set-IIBRoot` command associates a name (a.k.a RootName) with a path so that the name is resolved to the path when perform search in IIB project resources.

`Get-IIBRoot` on the other hand shows the path for a specified name, and lists all configured name/path pairs when `-ALL` parameter is used.

### Get-IIBCallStack
The command `Get-IIBCallStack` searches and prints the call stack for the specified resource. It requires *IIBRoot* to be configured via `Set-IIBRoot`. If there is only one *IIBRoot* configured, then it is used by default when executing `Get-IIBCallStack`.
```PowerShell
Get-IIBCallStack -Resource <Flow_or_Routine_Name>
Get-IIBCallStack -Resource <Flow_or_Routine_Name> -RootName <RootName>
```

### More Info
Use PowerShell's `Get-Command -Module PSIIB` to explore available commands, and `Get-Help <Cmdlet>` to find out the usage for each command.

## TODO
* Exclude the commented module/routine definitions and calls