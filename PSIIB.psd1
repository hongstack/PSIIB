#
# Module manifest for module 'PSIIB'
#
# Generated by: Hong Li
#
# Generated on: 21/09/2019
#

@{
    RootModule = 'PSIIB.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'dc220003-024a-4741-9eec-4589c635cd4a'
    Author = 'Hong Li'
    Copyright = '(c) 2019 Hong Li. All rights reserved.'
    Description = 'PSIIB provides PowerShell commands for working with IBM Integration Bus'
    PowerShellVersion = '5.1'

    FunctionsToExport = @('Get-IIBCallStack', 'Set-IIBRoot', 'Get-IIBRoot')
    CmdletsToExport   = @()
    VariablesToExport = '*'
    AliasesToExport   = @('iibcs')

	PrivateData = @{
        PSData = @{
            Tags         = 'PowerShell', 'IBM Integration Bus', 'IIB', 'PSEdition_Core', 'PSEdition_Desktop', 'Windows'
			LicenseUri   = 'https://github.com/hongstack/PSIIB/blob/master/LICENSE'
			ProjectUri   = 'https://github.com/hongstack/PSIIB'
            ReleaseNotes = 'https://github.com/hongstack/PSIIB/releases/tag/1.0.0'
        }
    }
}