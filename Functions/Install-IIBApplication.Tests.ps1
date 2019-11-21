InModuleScope PSIIB {
    Describe "IIB deployment management" -Tags ('Deployment') {
        $Node = 'TESTNODE'
        $Server = 'default'
        $Resource = 'App1'

        Context "resource list" {
            It "Gets IIB deployed resources" {
                Mock Invoke-IIBCommand {
                    "BIP1275I: Application 'APP_1' on integration server 'default' is running.",
                    "BIP1275I: Application 'APP_2' on integration server 'default' is running.",
                    "BIP1273I: Shared library 'LIB_1' is deployed to integration server 'default'.",
                    "BIP1273I: Shared library 'LIB_2' is deployed to integration server 'default'.",
                    "BIP1274I: Library 'LIB_3' is deployed to integration server 'default'.",
                    "",
                    "BIP8071I: Successful command completion."
                } -ParameterFilter {$IIBCmd -eq "mqsilist $Node -e $Server"}

                $DeployedResources = Get-IIBDeployedResources -Node $Node -Server $Server
                $DeployedApps = $DeployedResources[0]
                $DeployedLibs = $DeployedResources[1]

                Assert-MockCalled Invoke-IIBCommand -Exactly -Times 1
                $DeployedApps | Should -Be @('APP_1', 'APP_2')
                $DeployedLibs | Should -Be @('LIB_1', 'LIB_2')
            }
        }

        Context "application package" {
            It "Creates new BAR file for IIB application" {
                $RootLocation = "$TestDrive\iib\projects"
                $BarLocation = "$TestDrive\$(Get-Random)"
                $BarFullName = "$BarLocation\$Resource.bar"

                Mock Invoke-IIBCommand {} -ParameterFilter {$IIBCmd -eq "mqsipackagebar -w $RootLocation -a $BarFullName -k $Resource"}

                $Result = New-IIBBarFile -Resource $Resource -RootLocation $RootLocation -BarLocation $BarLocation 6>$null

                Assert-MockCalled Invoke-IIBCommand -Exactly -Times 1
                $Result | Should -Be $BarFullName
            }
        }

        Context "application installation" {
            It "Installs IIB application" {
                $BarFullName = "$TestDrive\$(Get-Random)\App1.bar"

                Mock Invoke-IIBCommand {} -ParameterFilter {$IIBCmd -eq "mqsideploy $Node -e $Server -a $BarFullName"}

                Install-IIBResource -BarFullName $BarFullName -Node $Node -Server $Server 6>$null

                Assert-MockCalled Invoke-IIBCommand -Exactly -Times 1
            }
        }

        Context "application uninstallation" {
            It "UnInstalls IIB application" {
                Mock Invoke-IIBCommand {} -ParameterFilter {$IIBCmd -eq "mqsideploy $Node -e $Server -d $Resource"}

                UnInstall-IIBResource -Resource $Resource -Node $Node -Server $Server 6>$null

                Assert-MockCalled Invoke-IIBCommand -Exactly -Times 1
            }
        }

        Context "flow monitoring enablement" {
            It "Enable monitoring of message flow" {
                Mock Invoke-IIBCommand {} -ParameterFilter {$IIBCmd -eq "mqsichangeflowmonitoring $Node -e $Server -c active -j"}

                Enable-IIBFlowMonitoring -Node $Node -Server $Server 6>$null

                Assert-MockCalled Invoke-IIBCommand -Exactly -Times 1
            }
        }

        Context "flow monitoring report" {
            It "Gets monitoring status of message flow" {
                Mock Invoke-IIBCommand {} -ParameterFilter {$IIBCmd -eq "mqsireportflowmonitoring $Node -e $Server"}

                Get-IIBFlowMonitoring -Node $Node -Server $Server 6>$null

                Assert-MockCalled Invoke-IIBCommand -Exactly -Times 1
            }
        }
    }

    Describe "IIB application installation" -Tags ('Deployment', 'AppInst') {
        $RootPath = "$TestDrive\iib\projects"
        Mock Get-IIBRoot { $RootPath }
        Mock Get-IIBDeployedResources {
            @('App1', 'App2'),
            @('Lib1', 'Lib2')
        }
        Mock New-IIBBarFile { "$env:TEMP\$Resource.bar" }
        Mock Install-IIBResource {}
        Mock UnInstall-IIBResource {}
        Mock Enable-IIBFlowMonitoring {}

        It "Installs IIB application" {
            New-Item -Path "$RootPath\App3" -ItemType Directory
            '<ns2:appDescriptor xmlns="http://com.ibm.etools.mft.descriptor.base" xmlns:ns2="...">',
            '  <references>',
            '    <sharedLibraryReference><libraryName>Lib1</libraryName></sharedLibraryReference>',
            '    <sharedLibraryReference><libraryName>Lib3</libraryName></sharedLibraryReference>',
            '  </references>',
            '</ns2:appDescriptor>' | Set-Content -Path "$RootPath\App3\application.descriptor"

            'App3' | Install-IIBApplication -Exclusive -FlowMonitoring

            Assert-MockCalled New-IIBBarFile -ParameterFilter {$Resource -eq 'Lib3'}                -Exactly -Times 1 -Scope It
            Assert-MockCalled Install-IIBResource -ParameterFilter {$BarFullName -like '*Lib3.bar'} -Exactly -Times 1 -Scope It

            Assert-MockCalled New-IIBBarFile -ParameterFilter {$Resource -eq 'App3'}                -Exactly -Times 1 -Scope It
            Assert-MockCalled Install-IIBResource -ParameterFilter {$BarFullName -like '*App3.bar'} -Exactly -Times 1 -Scope It

            Assert-MockCalled UnInstall-IIBResource -ParameterFilter {$Resource -eq 'Lib2'} -Exactly -Times 1 -Scope It
            Assert-MockCalled UnInstall-IIBResource -ParameterFilter {$Resource -eq 'App1'} -Exactly -Times 1 -Scope It
            Assert-MockCalled UnInstall-IIBResource -ParameterFilter {$Resource -eq 'App2'} -Exactly -Times 1 -Scope It
            Assert-MockCalled Enable-IIBFlowMonitoring -Exactly -Times 1 -Scope It
        }

        It "Throws exception when install non-IIB application" {
            Mock Test-Path {$false} -ParameterFilter {$Path -eq "$RootPath\App3\application.descriptor"}

            'App3' | Install-IIBApplication -Exclusive -FlowMonitoring -ErrorVariable err -ErrorAction SilentlyContinue

            $err.Count | Should -Be 1
            $err[0].Exception.Message | Should -Be "App3 is not an IIB application"

            Assert-MockCalled New-IIBBarFile -ParameterFilter {$Resource -eq 'App3'} -Exactly 0 -Scope It

            Assert-MockCalled UnInstall-IIBResource -ParameterFilter {$Resource -match 'Lib[1|2]'} -Exactly -Times 2 -Scope It
            Assert-MockCalled UnInstall-IIBResource -ParameterFilter {$Resource -match 'App[1|2]'} -Exactly -Times 2 -Scope It
            Assert-MockCalled Enable-IIBFlowMonitoring -Exactly -Times 1 -Scope It
        }
    }
}