Configuration SMB {

    [CmdletBinding()]

    Param (
        [string] $NodeName = "localhost",
        [string] $domainName,
        [string] $domainNameLabel,
        [string] $location,
        [System.Management.Automation.PSCredential]$domainAdminCredentials,
        [string] $OMSWorkSpaceId,
        [string] $OMSWorkSpaceKey
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration, xActiveDirectory,xComputerManagement,cRemoteDesktopServices,xCredSSP,xNetworking,xPSDesiredStateConfiguration,WindowsDefender
    $DependsOnAD = ""
    $DomainCred = new-object pscredential "$domainName\$($domainAdminCredentials.UserName)",$domainAdminCredentials.Password
    $OSVersion = new-object Version ((Get-CimInstance Win32_OperatingSystem).version)
    Node $NodeName {
        LocalConfigurationManager {
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
            ActionAfterReboot = 'ContinueConfiguration'
            AllowModuleOverwrite = $true
        }
        # Disable defender on Server 2016 during the configuration to speed-up the operations
        if($OSVersion.Major -ge 10){
            WindowsDefender DisableDefender {
                IsSingleInstance = "yes"
                DisableRealtimeMonitoring = $true
                ScanOnlyIfIdleEnabled = $true
            }
        }
        Registry CredSSPEnableNTLMDelegation1 {
            Ensure      = "Present"  # You can also set Ensure to "Absent"
            Key         = "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation"
            ValueName   = "AllowFreshCredentialsWhenNTLMOnly"
            ValueData   = "1"
            ValueType = 'Dword' 
        }
        Registry CredSSPEnableNTLMDelegation2 {
            Ensure      = "Present"  # You can also set Ensure to "Absent"
            Key         = "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation"
            ValueName   = "ConcatenateDefaults_AllowFreshNTLMOnly"
            ValueData   = "1"
            ValueType = 'Dword' 
        }
        Registry CredSSPEnableNTLMDelegation3 {
            Ensure      = "Present"  # You can also set Ensure to "Absent"
            Key         = "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly"
            ValueName   = "1"
            ValueData   = "WSMAN/*"
            ValueType = 'String'
        }
        xCredSSP Server { 
            Ensure = "Present" 
            Role = "Server"
            DependsOn = '[Registry]CredSSPEnableNTLMDelegation1','[Registry]CredSSPEnableNTLMDelegation2','[Registry]CredSSPEnableNTLMDelegation3'
        } 
        xCredSSP Client {
            Ensure = "Present"
            Role = "Client"
            DelegateComputers = "*"
            DependsOn = '[Registry]CredSSPEnableNTLMDelegation1','[Registry]CredSSPEnableNTLMDelegation2','[Registry]CredSSPEnableNTLMDelegation3'
        }
        Service OIService {
            Name = "HealthService"
            State = "Running"
            DependsOn = "[Package]OI"
        }
        xRemoteFile OIPackage {
            Uri = "http://download.microsoft.com/download/0/C/0/0C072D6E-F418-4AD4-BCB2-A362624F400A/MMASetup-AMD64.exe"
            DestinationPath = "C:\MMASetup-AMD64.exe"
        }
        Package OI {
            Ensure = "Present"
            Path  = "C:\MMASetup-AMD64.exe"
            Name = "Microsoft Monitoring Agent"
            ProductId = "8A7F2C51-4C7D-4BFD-9014-91D11F24AAE2"
            Arguments = '/C:"setup.exe /qn ADD_OPINSIGHTS_WORKSPACE=1 OPINSIGHTS_WORKSPACE_ID=' + $OMSWorkSpaceId + ' OPINSIGHTS_WORKSPACE_KEY=' + $OMSWorkSpaceKey + ' AcceptEndUserLicenseAgreement=1"'
            DependsOn = "[xRemoteFile]OIPackage"
        }
        xComputer DomainJoin {
            Name = $NodeName
            DomainName = $DomainName
            Credential = $DomainCred
        }
        $DependsOnAD = "[xComputer]DomainJoin"
        WindowsFeature Remote-Desktop-Services {
            Ensure = "Present"
            Name = "Remote-Desktop-Services"
            DependsOn = $DependsOnAD
        }
        WindowsFeature RDS-RD-Server {
            Ensure = "Present"
            Name = "RDS-RD-Server"
            DependsOn = $DependsOnAD
        }
        if($OSVersion.Major -lt 10){
            WindowsFeature Desktop-Experience {
                Ensure = "Present"
                Name = "Desktop-Experience"
                 DependsOn = $DependsOnAD
            }
        }
        WindowsFeature RSAT-RDS-Tools {
            Ensure = "Present"
            Name = "RSAT-RDS-Tools"
            IncludeAllSubFeature = $true
            DependsOn = $DependsOnAD
        }
        
    # WaitForAll RDS {
    #     ResourceName = "[cRDSessionDeployment]Deployment"
    #     NodeName = $Node.ConnectionBroker
    #     RetryIntervalSec = 60
    #     RetryCount = 10
    # }

        cRDSessionHost Deployment {
            Ensure = "Present"
            Credential = $DomainCred
            ConnectionBroker     = $Node.ConnectionBroker
            SessionHost          = $Node.NodeName
            DependsOn = "[WindowsFeature]Remote-Desktop-Services", "[WindowsFeature]RDS-RD-Server",$DependsOnAD
        }
        if($OSVersion.Major -ge 10){
            WindowsDefender EnableDefender {
                IsSingleInstance = "no"
                DisableRealtimeMonitoring = $false
                ScanOnlyIfIdleEnabled = $true
            }
        }
    }
}







   