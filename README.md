# PSIIB
**PSIIB** is a PowerShell module that provides commands for working with IBM Integration Bus.

## Overview
IBM Integration Bus Toolkit is not able to provide support when navigating between message flows and ESQL code during development. **PSIIB** is intended to bridge this gap and simplify the development work with IBM Integration Bus.

## Installation
Clone or download [PSIIB](https://github.com/hongstack/PSIIB/archive/master.zip), decompress it if downloaded, then copy it to: `C:\Users\$env:USERNAME\Documents\WindowsPowerShell\Modules`.

If the [PSLocalModule](https://github.com/hongstack/PSLocalModule) is installed, it only needs to run the following command:
```PowerShell
Set-PSCodePath <parent_dir_to_PSIIB>
Import-LocalModule PSIIB
```

## Usage
Use PowerShell's `Get-Command -Module PSIIB` to explore available commands, and `Get-Help <Cmdlet>` to find out the usage for each command.